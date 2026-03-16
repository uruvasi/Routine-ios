//
//  RoutineListView.swift
//  Routine-ios
//

import SwiftUI

private struct EditContext: Identifiable {
    let routine: Routine
    let isNew: Bool
    var id: UUID { routine.id }
}

struct RoutineListView: View {
    @Environment(RoutineStore.self) var routineStore
    @Environment(SettingsStore.self) var settingsStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var editContext: EditContext?
    @State private var activeVM: TimerViewModel?
    @State private var showTimer = false
    @State private var deleteTarget: Routine?

    private var l: L { settingsStore.l }

    var body: some View {
        List {
            ForEach(routineStore.routines) { routine in
                RoutineRowView(
                    routine: routine,
                    isActive: activeVM?.routine.id == routine.id && activeVM?.isFinished == false,
                    onRun: { startRoutine(routine) },
                    onEdit: { editContext = EditContext(routine: routine, isNew: false) }
                )
            }
            .onMove { source, dest in
                routineStore.reorderRoutines(from: source, to: dest)
            }
            .onDelete { indexSet in
                indexSet.forEach { i in
                    routineStore.deleteRoutine(id: routineStore.routines[i].id)
                }
            }
        }
        .navigationTitle(l.routinesTab)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { EditButton() }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editContext = EditContext(routine: Routine(name: ""), isNew: true)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .overlay {
            if routineStore.routines.isEmpty {
                ContentUnavailableView(
                    l.noRoutines,
                    systemImage: "list.bullet.clipboard"
                )
            }
        }
        // ミニプレイヤー（タイマー実行中かつタイマー画面を閉じているとき）
        .safeAreaInset(edge: .bottom) {
            if let vm = activeVM, !vm.isFinished, !showTimer {
                MiniPlayerView(vm: vm) {
                    showTimer = true
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .sheet(item: $editContext) { ctx in
            NavigationStack {
                RoutineEditorView(routine: ctx.routine, isNew: ctx.isNew)
            }
        }
        .fullScreenCover(isPresented: $showTimer) {
            if let vm = activeVM {
                RoutineTimerView(vm: vm) {
                    showTimer = false
                    if vm.isFinished { activeVM = nil }
                }
            }
        }
        .onAppear {
            // アプリ kill → 再起動時にタイマー状態を自動復元
            if activeVM == nil,
               let savedId = UserDefaults.standard.string(forKey: "timer_routineId"),
               let uuid = UUID(uuidString: savedId),
               let routine = routineStore.routines.first(where: { $0.id == uuid }) {
                let vm = TimerViewModel(routine: routine, alarmBehavior: settingsStore.alarmBehavior, startSoundPreset: settingsStore.startSoundPreset)
                vm.didForeground()
                activeVM = vm
            }
        }
        // バックグラウンド / フォアグラウンド処理
        .onChange(of: scenePhase) { _, newPhase in
            guard let vm = activeVM, !vm.isFinished else { return }
            switch newPhase {
            case .background:
                vm.willBackground()
            case .active:
                vm.didForeground()
            default:
                break
            }
        }
        // タイマーがフィニッシュしてミニプレイヤー表示中なら vm をクリア
        .onChange(of: activeVM?.isFinished) { _, isFinished in
            if isFinished == true && !showTimer {
                activeVM = nil
            }
        }
    }

    private func startRoutine(_ routine: Routine) {
        activeVM = TimerViewModel(routine: routine, alarmBehavior: settingsStore.alarmBehavior, startSoundPreset: settingsStore.startSoundPreset)
        showTimer = true
    }
}

// MARK: - Mini Player

private struct MiniPlayerView: View {
    let vm: TimerViewModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: vm.isRunning ? "play.circle.fill" : "pause.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.indigo)

                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.routine.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(vm.currentTask?.name ?? "")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }

                Spacer()

                Text(timeString(vm.remaining))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.up")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let total = Int(ceil(interval))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Routine Row

private struct RoutineRowView: View {
    @Environment(SettingsStore.self) var settingsStore
    let routine: Routine
    let isActive: Bool
    let onRun: () -> Void
    let onEdit: () -> Void

    private var l: L { settingsStore.l }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(routine.name.isEmpty ? l.newRoutine : routine.name)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                onRun()
            } label: {
                Image(systemName: isActive ? "waveform" : "play.fill")
                    .foregroundStyle(routine.tasks.isEmpty ? Color.secondary : Color.indigo)
                    .symbolEffect(.variableColor.iterative, isActive: isActive)
            }
            .disabled(routine.tasks.isEmpty)
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
    }

    private var subtitle: String {
        let count = routine.tasks.count
        let total = RoutineTask(name: "", duration: routine.totalDuration)
            .formattedDuration(lang: settingsStore.language)
        return "\(count) \(l.tasks) · \(l.total): \(total)"
    }
}
