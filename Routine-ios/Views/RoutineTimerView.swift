//
//  RoutineTimerView.swift
//  Routine-ios
//

import SwiftUI
import UserNotifications

// MARK: - ViewModel

@MainActor
class TimerViewModel: ObservableObject {
    @Published var taskIndex: Int = 0
    @Published var remaining: TimeInterval
    @Published var isRunning = false
    @Published var isFinished = false

    let routine: Routine
    private var taskEndDate: Date?
    private var timer: Timer?

    init(routine: Routine) {
        self.routine = routine
        self.remaining = TimeInterval(routine.tasks.first?.duration ?? 0)
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
        taskEndDate = Date().addingTimeInterval(remaining)
        isRunning = true
        scheduleTimer()
        scheduleNotification(task: task, after: remaining, lang: lang)
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
        cancelNotification()
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

    // MARK: - Private

    private func jump(to index: Int, lang: AppLanguage) {
        let wasRunning = isRunning
        if wasRunning { timer?.invalidate(); timer = nil; cancelNotification() }

        taskIndex = index
        let dur = TimeInterval(routine.tasks[index].duration)
        remaining = dur

        if wasRunning {
            let task = routine.tasks[index]
            taskEndDate = Date().addingTimeInterval(dur)
            scheduleTimer()
            scheduleNotification(task: task, after: dur, lang: lang)
            AudioAlertManager.shared.playStart()
            AudioAlertManager.shared.speak(L(lang: lang).speakTaskStart(task.name), lang: lang)
        } else {
            taskEndDate = nil
        }
    }

    private func finish(lang: AppLanguage) {
        timer?.invalidate(); timer = nil
        isRunning = false
        isFinished = true
        taskEndDate = nil
        cancelNotification()
        AudioAlertManager.shared.playEnd()
        AudioAlertManager.shared.speak(L(lang: lang).speakFinished(), lang: lang)
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    private func tick() {
        guard isRunning, let endDate = taskEndDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining <= 0 {
            // auto-advance — lang unknown here, read from settings at call site via notification
            let nextIndex = taskIndex + 1
            if nextIndex < routine.tasks.count {
                // advance without TTS (notification handles it)
                taskIndex = nextIndex
                let dur = TimeInterval(routine.tasks[nextIndex].duration)
                remaining = dur
                taskEndDate = Date().addingTimeInterval(dur)
                AudioAlertManager.shared.playEnd()
            } else {
                timer?.invalidate(); timer = nil
                isRunning = false
                isFinished = true
                taskEndDate = nil
                AudioAlertManager.shared.playEnd()
            }
        }
    }

    // MARK: - Local notifications (Watch も受け取る)

    private func scheduleNotification(task: RoutineTask, after interval: TimeInterval, lang: AppLanguage) {
        cancelNotification()
        let content = UNMutableNotificationContent()
        content.title = task.name
        content.body = lang == .ja ? "完了しました" : "Completed"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
        let req = UNNotificationRequest(identifier: "task-complete", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["task-complete"])
    }
}

// MARK: - View

struct RoutineTimerView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @StateObject private var vm: TimerViewModel
    let onBack: () -> Void

    init(routine: Routine, onBack: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: TimerViewModel(routine: routine))
        self.onBack = onBack
    }

    private var l: L { settingsStore.l }
    private var lang: AppLanguage { settingsStore.language }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack(spacing: 32) {
                // Header
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
    }

    // MARK: - Sub-views

    private var timerView: some View {
        VStack(spacing: 40) {
            // Task name
            Text(vm.currentTask?.name ?? "")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Progress ring + time
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

            // Controls
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
