//
//  RoutineEditorView.swift
//  Routine-ios
//

import SwiftUI

struct RoutineEditorView: View {
    @EnvironmentObject var routineStore: RoutineStore
    @EnvironmentObject var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss

    let originalRoutine: Routine
    let isNew: Bool

    @State private var name: String
    @State private var tasks: [RoutineTask]
    @State private var showDeleteConfirm = false
    @State private var durationPickerTask: RoutineTask?

    private var l: L { settingsStore.l }

    init(routine: Routine, isNew: Bool) {
        self.originalRoutine = routine
        self.isNew = isNew
        _name = State(initialValue: routine.name)
        _tasks = State(initialValue: routine.tasks)
    }

    var body: some View {
        Form {
            Section(l.routineNamePlaceholder) {
                TextField(l.routineNamePlaceholder, text: $name)
            }

            Section(l.tasks2) {
                ForEach($tasks) { $task in
                    TaskRowEditor(
                        task: $task,
                        lang: settingsStore.language,
                        onPickDuration: { durationPickerTask = task }
                    )
                }
                .onMove { source, dest in
                    tasks.move(fromOffsets: source, toOffset: dest)
                }
                .onDelete { indexSet in
                    tasks.remove(atOffsets: indexSet)
                }

                Button {
                    tasks.append(RoutineTask(name: "", duration: 60))
                } label: {
                    Label(l.addTask, systemImage: "plus")
                }
            }

            if !isNew {
                Section {
                    Button(l.deleteRoutine, role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
        }
        .navigationTitle(isNew ? l.newRoutine : l.editRoutine)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(l.cancel) { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(l.done) { save() }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ToolbarItem(placement: .keyboard) {
                EditButton()
            }
        }
        .environment(\.editMode, .constant(.active))
        .confirmationDialog(l.confirmDeleteRoutine, isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(l.delete, role: .destructive) {
                routineStore.deleteRoutine(id: originalRoutine.id)
                dismiss()
            }
            Button(l.cancel, role: .cancel) {}
        }
        .sheet(item: $durationPickerTask) { task in
            DurationPickerSheet(task: task) { updated in
                if let i = tasks.firstIndex(where: { $0.id == updated.id }) {
                    tasks[i] = updated
                }
            }
        }
    }

    private func save() {
        var updated = originalRoutine
        updated.name = name.trimmingCharacters(in: .whitespaces)
        updated.tasks = tasks
        if isNew {
            routineStore.addRoutine(updated)
        } else {
            routineStore.updateRoutine(updated)
        }
        dismiss()
    }
}

// MARK: - Task row inside editor

private struct TaskRowEditor: View {
    @Binding var task: RoutineTask
    let lang: AppLanguage
    let onPickDuration: () -> Void

    var body: some View {
        HStack {
            TextField(L(lang: lang).taskNamePlaceholder, text: $task.name)
            Spacer()
            Button {
                onPickDuration()
            } label: {
                Text(task.formattedDuration(lang: lang))
                    .foregroundStyle(.indigo)
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Duration picker sheet

private struct DurationPickerSheet: View {
    let task: RoutineTask
    let onSave: (RoutineTask) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var minutes: Int
    @State private var seconds: Int

    init(task: RoutineTask, onSave: @escaping (RoutineTask) -> Void) {
        self.task = task
        self.onSave = onSave
        _minutes = State(initialValue: task.duration / 60)
        _seconds = State(initialValue: task.duration % 60)
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("", selection: $minutes) {
                    ForEach(0..<100) { m in
                        Text("\(m)分").tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Picker("", selection: $seconds) {
                    ForEach([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self) { s in
                        Text("\(s)秒").tag(s)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .padding()
            .navigationTitle(task.name.isEmpty ? "時間を設定" : task.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        var updated = task
                        updated.duration = max(5, minutes * 60 + seconds)
                        onSave(updated)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.4)])
    }
}
