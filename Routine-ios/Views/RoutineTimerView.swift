//
//  RoutineTimerView.swift
//  Routine-ios
//

import SwiftUI
import AlarmKit

// MARK: - ViewModel

@MainActor @Observable
class TimerViewModel {
    var taskIndex: Int = 0
    var remaining: TimeInterval
    var isRunning = false
    var isFinished = false

    let routine: Routine
    private let alarmBehavior: AlarmBehavior
    private let startSoundPreset: StartSoundPreset
    private(set) var taskEndDate: Date?
    private var timer: Timer?

    // UserDefaults キー（アプリ kill 後の状態復元用）
    private static let keyIndex   = "timer_taskIndex"
    private static let keyEndDate = "timer_taskEndDate"
    private static let keyRoutineId = "timer_routineId"

    init(routine: Routine, alarmBehavior: AlarmBehavior = .finalOnly, startSoundPreset: StartSoundPreset = .beep) {
        self.routine = routine
        self.alarmBehavior = alarmBehavior
        self.startSoundPreset = startSoundPreset

        // 同じルーティンの実行中状態が保存されていれば復元
        let savedId = UserDefaults.standard.string(forKey: Self.keyRoutineId)
        if savedId == routine.id.uuidString,
           let endDate = UserDefaults.standard.object(forKey: Self.keyEndDate) as? Date,
           let idx = UserDefaults.standard.object(forKey: Self.keyIndex) as? Int,
           idx < routine.tasks.count {
            self.taskIndex   = idx
            self.taskEndDate = endDate
            self.remaining   = max(0, endDate.timeIntervalSinceNow)
            self.isRunning   = true
        } else {
            self.remaining = TimeInterval(routine.tasks.first?.duration ?? 0)
        }
    }

    var currentTask: RoutineTask? {
        guard taskIndex < routine.tasks.count else { return nil }
        return routine.tasks[taskIndex]
    }

    var progress: Double {
        guard let task = currentTask, task.duration > 0 else { return 0 }
        return 1.0 - remaining / TimeInterval(task.duration)
    }

    var taskTotal: Int { routine.tasks.count }

    // MARK: - Controls

    func togglePlayPause() {
        isRunning ? pause() : start()
    }

    func start() {
        guard !isFinished, let task = currentTask else { return }
        taskEndDate = Date().addingTimeInterval(remaining)
        isRunning = true
        scheduleTimer()
        if shouldAlarm(for: taskIndex) {
            scheduleAlarm(task: task, index: taskIndex, at: taskEndDate!)
        }
        persistState()
        sendWatchState()
        AudioAlertManager.shared.playStart(preset: startSoundPreset)
    }

    func pause() {
        if let endDate = taskEndDate {
            remaining = max(0, endDate.timeIntervalSinceNow)
        }
        taskEndDate = nil
        isRunning = false
        timer?.invalidate()
        timer = nil
        Task { await cancelAllAlarms() }
        clearPersistedState()
        sendWatchState()
    }

    func next() {
        let nextIndex = taskIndex + 1
        if nextIndex < routine.tasks.count {
            jump(to: nextIndex)
        } else {
            finish()
        }
    }

    func prev() {
        if taskIndex > 0 {
            jump(to: taskIndex - 1)
        }
    }

    // MARK: - Background / Foreground

    /// バックグラウンド移行時: 残り全タスクのアラームを一括スケジュール・状態を永続化
    func willBackground() {
        guard isRunning, !isFinished, let endDate = taskEndDate else { return }
        persistState()
        Task {
            await cancelAllAlarms()
            // 現在タスクの残り時間を基点に、タスクごとの countdownDuration を累積計算
            var totalDuration = endDate.timeIntervalSinceNow
            for i in taskIndex..<routine.tasks.count {
                let task = routine.tasks[i]
                if shouldAlarm(for: i) {
                    let config = AlarmManager.AlarmConfiguration.timer(
                        duration: max(1, totalDuration),
                        attributes: makeAlarmAttributes(task: task)
                    )
                    try? await AlarmManager.shared.schedule(id: alarmID(for: i), configuration: config)
                }
                if i + 1 < routine.tasks.count {
                    totalDuration += TimeInterval(routine.tasks[i + 1].duration)
                }
            }
        }
    }

    /// フォアグラウンド復帰 / アプリ起動時: 経過タスクを計算して状態を補正
    func didForeground() {
        guard isRunning, let endDate = taskEndDate else { return }
        Task { await cancelAllAlarms() }

        var currentEndDate = endDate
        var currentIndex = taskIndex

        while Date() >= currentEndDate {
            if currentIndex + 1 < routine.tasks.count {
                currentIndex += 1
                currentEndDate = currentEndDate.addingTimeInterval(
                    TimeInterval(routine.tasks[currentIndex].duration)
                )
            } else {
                finish()
                return
            }
        }

        if currentIndex != taskIndex {
            taskIndex = currentIndex
            taskEndDate = currentEndDate
            AudioAlertManager.shared.playEnd()
        }

        remaining = max(0, currentEndDate.timeIntervalSinceNow)
        persistState()
        sendWatchState()

        if let task = currentTask, shouldAlarm(for: taskIndex) {
            scheduleAlarm(task: task, index: taskIndex, at: taskEndDate!)
        }
        scheduleTimer()
    }

    // MARK: - Private

    private func jump(to index: Int) {
        let wasRunning = isRunning
        if wasRunning { timer?.invalidate(); timer = nil; Task { await cancelAllAlarms() } }

        taskIndex = index
        let dur = TimeInterval(routine.tasks[index].duration)
        remaining = dur

        if wasRunning {
            let task = routine.tasks[index]
            taskEndDate = Date().addingTimeInterval(dur)
            scheduleTimer()
            if shouldAlarm(for: index) {
                scheduleAlarm(task: task, index: index, at: taskEndDate!)
            }
            persistState()
            sendWatchState()
            AudioAlertManager.shared.playStart(preset: startSoundPreset)
        } else {
            taskEndDate = nil
            sendWatchState()
        }
    }

    private func finish() {
        timer?.invalidate(); timer = nil
        isRunning = false
        isFinished = true
        taskEndDate = nil
        Task { await cancelAllAlarms() }
        clearPersistedState()
        sendWatchState()
        AudioAlertManager.shared.playEnd()
    }

    private func sendWatchState() {
        PhoneSessionManager.shared.sendTimerState(
            routineName: routine.name,
            taskName: currentTask?.name ?? "",
            taskIndex: taskIndex,
            taskTotal: taskTotal,
            taskEndDate: taskEndDate,
            taskDuration: currentTask?.duration ?? 0,
            isRunning: isRunning,
            isFinished: isFinished
        )
    }

    /// `.common` モードで登録することで、スクロール中・バックグラウンド移行直後なども発火する
    private func scheduleTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard isRunning, let endDate = taskEndDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining <= 0 {
            let nextIndex = taskIndex + 1
            if nextIndex < routine.tasks.count {
                taskIndex = nextIndex
                let task = routine.tasks[nextIndex]
                let dur = TimeInterval(task.duration)
                remaining = dur
                taskEndDate = Date().addingTimeInterval(dur)
                if shouldAlarm(for: nextIndex) {
                    scheduleAlarm(task: task, index: nextIndex, at: taskEndDate!)
                }
                persistState()
                sendWatchState()
                AudioAlertManager.shared.playEnd()
            } else {
                finish()
            }
        }
    }

    // MARK: - Persistence

    private func persistState() {
        UserDefaults.standard.set(routine.id.uuidString, forKey: Self.keyRoutineId)
        UserDefaults.standard.set(taskIndex,   forKey: Self.keyIndex)
        UserDefaults.standard.set(taskEndDate, forKey: Self.keyEndDate)
    }

    private func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: Self.keyRoutineId)
        UserDefaults.standard.removeObject(forKey: Self.keyIndex)
        UserDefaults.standard.removeObject(forKey: Self.keyEndDate)
    }

    // MARK: - AlarmKit

    private func shouldAlarm(for index: Int) -> Bool {
        switch alarmBehavior {
        case .everyTask: return true
        case .finalOnly: return index == routine.tasks.count - 1
        case .off:       return false
        }
    }

    private func alarmID(for index: Int) -> UUID {
        let b = routine.id.uuid
        return UUID(uuid: (b.0,b.1,b.2,b.3,b.4,b.5,b.6,b.7,
                           b.8,b.9,b.10,b.11,b.12,b.13,b.14,
                           UInt8((Int(b.15) ^ (index & 0xFF)) & 0xFF)))
    }

    private func makeAlarmAttributes(task: RoutineTask) -> AlarmAttributes<RoutineAlarmMetadata> {
        let title: LocalizedStringResource = "\(task.name)"
        let alert = AlarmPresentation.Alert(
            title: title,
            stopButton: AlarmButton(text: "OK", textColor: .white, systemImageName: "checkmark")
        )
        return AlarmAttributes<RoutineAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: RoutineAlarmMetadata(taskName: task.name, routineName: routine.name),
            tintColor: .indigo
        )
    }

    private func scheduleAlarm(task: RoutineTask, index: Int, at fireDate: Date) {
        let duration = max(1, fireDate.timeIntervalSinceNow)
        let config = AlarmManager.AlarmConfiguration.timer(duration: duration, attributes: makeAlarmAttributes(task: task))
        Task { try? await AlarmManager.shared.schedule(id: alarmID(for: index), configuration: config) }
    }

    private func cancelAllAlarms() async {
        for i in 0..<routine.tasks.count {
            try? await AlarmManager.shared.stop(id: alarmID(for: i))
        }
    }
}

// MARK: - View

struct RoutineTimerView: View {
    @Environment(SettingsStore.self) var settingsStore
    let vm: TimerViewModel
    let onBack: () -> Void

    private var l: L { settingsStore.l }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack(spacing: 32) {
                HStack {
                    Button(l.backToList) { onBack() }
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(vm.taskIndex + 1) / \(vm.taskTotal)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Spacer()

                if vm.isFinished {
                    finishedView
                } else {
                    timerView
                }

                Spacer()
            }
            .padding(.top)
        }
        .onAppear {
            // 復元済み状態のファストフォワード（アプリ再起動後など）
            vm.didForeground()
            // Watch からのコマンドを受け取り TimerViewModel へ転送
            PhoneSessionManager.shared.onCommand = { [weak vm] cmd in
                guard let vm else { return }
                switch cmd {
                case WatchMessage.cmdToggle: vm.togglePlayPause()
                case WatchMessage.cmdNext:   vm.next()
                case WatchMessage.cmdPrev:   vm.prev()
                default: break
                }
            }
        }
        .onDisappear {
            PhoneSessionManager.shared.onCommand = nil
        }
    }

    // MARK: - Sub-views

    private var timerView: some View {
        VStack(spacing: 40) {
            Text(vm.currentTask?.name ?? "")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: vm.progress)
                    .stroke(Color.indigo, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: vm.progress)
                Text(timeString(vm.remaining))
                    .font(.system(size: 54, weight: .light, design: .monospaced))
                    .minimumScaleFactor(0.5)
            }
            .frame(width: 220, height: 220)

            HStack(spacing: 40) {
                Button {
                    vm.prev()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title)
                }
                .disabled(vm.taskIndex == 0)
                .foregroundStyle(vm.taskIndex == 0 ? .secondary : .primary)

                Button {
                    vm.togglePlayPause()
                } label: {
                    Image(systemName: vm.isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.indigo)
                }

                Button {
                    vm.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title)
                }
                .foregroundStyle(.primary)
            }
        }
    }

    private var finishedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.indigo)
            Text(l.finished)
                .font(.largeTitle)
                .fontWeight(.bold)
            Text(l.finishedBody)
                .foregroundStyle(.secondary)
            Button(l.backToList) { onBack() }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
        }
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let total = Int(ceil(interval))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
