//
//  RoutineStore.swift
//  Routine-ios
//

import Foundation
import Combine

class RoutineStore: ObservableObject {
    @Published var routines: [Routine] = []
    
    private let saveKey = "routines_v1"
    
    init() {
        load()
    }
    
    func addRoutine(_ routine: Routine) {
        routines.append(routine)
        save()
    }
    
    func updateRoutine(_ routine: Routine) {
        if let index = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[index] = routine
            save()
        }
    }
    
    func deleteRoutine(id: UUID) {
        routines.removeAll { $0.id == id }
        save()
    }
    
    func reorderRoutines(from source: IndexSet, to destination: Int) {
        routines.move(fromOffsets: source, toOffset: destination)
        save()
    }
    
    func resetAll() {
        routines = []
        save()
    }
    
    // MARK: - Persistence
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(routines) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Routine].self, from: data) {
            routines = decoded
        }
    }
    
    // MARK: - Import/Export
    
    func exportMarkdown() -> String {
        var md = "# Routines\n\n"
        for routine in routines {
            md += "## \(routine.name)\n\n"
            for task in routine.tasks {
                let dur = task.formattedDuration(lang: .ja)
                md += "- \(task.name) (\(dur))\n"
            }
            md += "\n"
        }
        return md
    }
    
    func importMarkdown(_ markdown: String, replace: Bool) {
        // Simple import logic - can be enhanced
        if replace {
            routines = []
        }
        // TODO: Implement markdown parsing if needed
        save()
    }
}
