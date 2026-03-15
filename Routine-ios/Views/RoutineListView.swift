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

    @State private var editContext: EditContext?
    @State private var runningRoutine: Routine?
    @State private var deleteTarget: Routine?

    private var l: L { settingsStore.l }

    var body: some View {
        List {
            ForEach(routineStore.routines) { routine in
                RoutineRowView(
                    routine: routine,
                    onRun: { runningRoutine = routine },
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
        .sheet(item: $editContext) { ctx in
            NavigationStack {
                RoutineEditorView(routine: ctx.routine, isNew: ctx.isNew)
            }
        }
        .fullScreenCover(item: $runningRoutine) { routine in
            RoutineTimerView(routine: routine) {
                runningRoutine = nil
            }
        }
    }
}

private struct RoutineRowView: View {
    @Environment(SettingsStore.self) var settingsStore
    let routine: Routine
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
                Image(systemName: "play.fill")
                    .foregroundStyle(routine.tasks.isEmpty ? Color.secondary : Color.indigo)
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
