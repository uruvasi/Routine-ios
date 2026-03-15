//
//  RoutineTimerView.swift
//  Routine-ios
//

import SwiftUI
import UserNotifications

// MARK: - ViewModel

@MainActor @Observable
class TimerViewModel {
    var taskIndex: Int = 0
    var remaining: TimeInterval
    var isRunning = false
    var isFinished = false

    let routine: Routine
    private(set) var taskEndDate: Date?
    private var timer: Timer?
    private(set) var lang: AppLanguage = .ja

    // UserDefaults キー（アプリ kill 後の状態復元用）
    private static let keyIndex   = "timer_taskIndex"
    private static let keyEndDate = "timer_taskEndDate"
    private static let keyRoutineId = "timer_routineId"

    init(routine: Routine) {
        self.routine = routine

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

    func togglePlayPause(lang: AppLanguage) {
        isRunning ? pause() : start(lang: lang)
    }

    func start(lang: AppLanguage) {
        guard !isFinished, let task = currentTask else { return }
        self.lang = lang
        taskEndDate = Date().addingTimeInterval(remaining)
        isRunning = true
        scheduleTimer()
        scheduleNotification(task: task, index: taskIndex, after: remaining, lang: lang)
        persistState()
        sendWatchState()
        AudioAlertManager.shared.playStart()
        AudioAlertManager.shared.speak(L(lang: lang).speakTaskStart(task.name), lang: lang)
    }

    func pause() {
        if let endDate = taskEndDate {
            remaining = max(0, endDate.timeIntervalSinceNow)
        }
        taskEndDate = nil
        isRunning = false
        timer?.invalidate()
        timer = nil
        cancelAllNotifications()
        clearPersistedState()
        sendWatchState()
    }

    func next(lang: AppLanguage) {
        let nextIndex = taskIndex + 1
        if nextIndex < routine.tasks.count {
            jump(to: nextIndex, lang: lang)
        } else {
            finish(lang: lang)
        }
    }

    func prev(lang: AppLanguage) {
        if taskIndex > 0 {
            jump(to: taskIndex - 1, lang: lang)
        }
    }

    // MARK: - Background / Foreground

    /// バックグラウンド移行時: 残り全タスクの通知を一括スケジュール・状態を永続化
    func willBackground(lang: AppLanguage) {
        guard isRunning, !isFinished, let endDate = taskEndDate else { return }
        persistState()
        cancelAllNotifications()

        // taskEndDate ベースで正確な遅延を計算
        var delay = endDate.timeIntervalSinceNow
        for i in taskIndex..<routine.tasks.count {
            let task = routine.tasks[i]
            let content = UNMutableNotificationContent()
            content.title = task.name
            content.body = lang == .ja ? "完了しました" : "Completed"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
            let req = UNNotificationRequest(identifier: "task-\(i)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(req)

            if i + 1 < routine.tasks.count {
                delay += TimeInterval(routine.tasks[i + 1].duration)
            }
        }
    }

    /// フォアグラウンド復帰 / アプリ起動時: 経過タスクを計算して状態を補正
    func didForeground(lang: AppLanguage) {
        self.lang = lang
        guard isRunning, let endDate = taskEndDate else { return }
        cancelAllNotifications()

        var currentEndDate = endDate
        var currentIndex = taskIndex

        while Date() >= currentEndDate {
            if currentIndex + 1 < routine.tasks.count {
                currentIndex += 1
                currentEndDate = currentEndDate.addingTimeInterval(
                    TimeInterval(routine.tasks[currentIndex].duration)
                )
            } else {
                finish(lang: lang)
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

        if let task = currentTask {
            scheduleNotification(task: task, index: taskIndex, after: remaining, lang: lang)
        }
        scheduleTimer()
    }

    // MARK: - Private

    private func jump(to index: Int, lang: AppLanguage) {
        let wasRunning = isRunning
        if wasRunning { timer?.invalidate(); timer = nil; cancelAllNotifications() }

        taskIndex = index
        let dur = TimeInterval(routine.tasks[index].duration)
        remaining = dur

        if wasRunning {
            let task = routine.tasks[index]
            taskEndDate = Date().addingTimeInterval(dur)
            scheduleTimer()
            scheduleNotification(task: task, index: index, after: dur, lang: lang)
            persistState()
            sendWatchState()
            AudioAlertManager.shared.playStart()
            AudioAlertManager.shared.speak(L(lang: lang).speakTaskStart(task.name), lang: lang)
        } else {
            taskEndDate = nil
            sendWatchState()
        }
    }

    private func finish(lang: AppLanguage) {
        timer?.invalidate(); timer = nil
        isRunning = false
        isFinished = true
        taskEndDate = nil
        cancelAllNotifications()
        clearPersistedState()
        sendWatchState()
        AudioAlertManager.shared.playEnd()
        AudioAlertManager.shared.speak(L(lang: lang).speakFinished(), lang: lang)
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
                scheduleNotification(task: task, index: nextIndex, after: dur, lang: lang)
                persistState()
                sendWatchState()
                AudioAlertManager.shared.playEnd()
                AudioAlertManager.shared.speak(L(lang: lang).speakTaskStart(task.name), lang: lang)
            } else {
                finish(lang: lang)
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

    // MARK: - Notifications

    private func scheduleNotification(task: RoutineTask, index: Int, after interval: TimeInterval, lang: AppLanguage) {
        let content = UNMutableNotificationContent()
        content.title = task.name
        content.body = lang == .ja ? "完了しました" : "Completed"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
        let req = UNNotificationRequest(identifier: "task-\(index)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    private func cancelAllNotifications() {
        let ids = (0..<routine.tasks.count).map { "task-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}

// MARK: - View

struct RoutineTimerView: View {
    @Environment(SettingsStore.self) var settingsStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var vm: TimerViewModel
    let onBack: () -> Void

    init(routine: Routine, onBack: @escaping () -> Void) {
        _vm = State(wrappedValue: TimerViewModel(routine: routine))
        self.onBack = onBack
    }

    private var l: L { settingsStore.l }
    private var lang: AppLanguage { settingsStore.language }

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
            AudioAlertManager.shared.speechRate = settingsStore.speechRate
            vm.didForeground(lang: lang)
            // Watch からのコマンドを受け取り TimerViewModel へ転送
            PhoneSessionManager.shared.onCommand = { [weak vm] cmd in
                guard let vm else { return }
                switch cmd {
                case WatchMessage.cmdToggle: vm.togglePlayPause(lang: vm.lang)
                case WatchMessage.cmdNext:   vm.next(lang: vm.lang)
                case WatchMessage.cmdPrev:   vm.prev(lang: vm.lang)
                default: break
                }
            }
        }
        .onDisappear {
            PhoneSessionManager.shared.onCommand = nil
        }
        .onChange(of: settingsStore.speechRate) { _, rate in
            AudioAlertManager.shared.speechRate = rate
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                vm.willBackground(lang: lang)
            case .active:
                vm.didForeground(lang: lang)
            default:
                break
            }
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
                    vm.prev(lang: lang)
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title)
                }
                .disabled(vm.taskIndex == 0)
                .foregroundStyle(vm.taskIndex == 0 ? .secondary : .primary)

                Button {
                    vm.togglePlayPause(lang: lang)
                } label: {
                    Image(systemName: vm.isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.indigo)
                }

                Button {
                    vm.next(lang: lang)
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
