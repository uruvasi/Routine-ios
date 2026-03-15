import Foundation
import Combine
import SwiftUI

class RoutineStore: ObservableObject {
    @Published var routines: [Routine] = []

    private let defaultsKey = "routines_v1"

    init() {
        load()
    }

    // MARK: - CRUD

    func addRoutine(_ routine: Routine) {
        routines.append(routine)
        save()
    }

    func updateRoutine(_ routine: Routine) {
        guard let index = routines.firstIndex(where: { $0.id == routine.id }) else { return }
        routines[index] = routine
        save()
    }

    func deleteRoutine(id: UUID) {
        routines.removeAll { $0.id == id }
        save()
    }

    func reorderRoutines(from source: IndexSet, to destination: Int) {
        routines.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // MARK: - Import / Export (Markdown)

    /// "# RoutineName\n- TaskName: Xm Ys\n..." 形式でエクスポート
    func exportMarkdown() -> String {
        routines.map { routine in
            let header = "# \(routine.name)"
            let tasks = routine.tasks.map { task in
                let m = task.duration / 60
                let s = task.duration % 60
                if m > 0 && s > 0 { return "- \(task.name): \(m)分\(s)秒" }
                if m > 0           { return "- \(task.name): \(m)分" }
                return "- \(task.name): \(s)秒"
            }.joined(separator: "\n")
            return [header, tasks].joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

    /// Markdown をパースしてインポート（append or replace）
    func importMarkdown(_ text: String, replace: Bool) {
        let parsed = parseMarkdown(text)
        if replace {
            routines = parsed
        } else {
            routines.append(contentsOf: parsed)
        }
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(routines) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode([Routine].self, from: data)
        else { return }
        routines = decoded
    }

    // MARK: - Private

    private func parseMarkdown(_ text: String) -> [Routine] {
        var result: [Routine] = []
        var currentName: String?
        var currentTasks: [RoutineTask] = []

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                if let name = currentName {
                    result.append(Routine(name: name, tasks: currentTasks))
                }
                currentName = String(trimmed.dropFirst(2))
                currentTasks = []
            } else if trimmed.hasPrefix("- "), let colonRange = trimmed.range(of: ": ") {
                let taskName = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<colonRange.lowerBound])
                let durationStr = String(trimmed[colonRange.upperBound...])
                let seconds = parseDuration(durationStr)
                if seconds > 0 {
                    currentTasks.append(RoutineTask(name: taskName, duration: seconds))
                }
            }
        }
        if let name = currentName {
            result.append(Routine(name: name, tasks: currentTasks))
        }
        return result
    }

    /// "1分30秒" / "1m 30s" / "90" などを秒に変換
    private func parseDuration(_ str: String) -> Int {
        var seconds = 0
        // 日本語: X分Y秒
        if let m = str.firstMatch(of: /(\d+)分/) { seconds += Int(m.1)! * 60 }
        if let s = str.firstMatch(of: /(\d+)秒/) { seconds += Int(s.1)! }
        if seconds > 0 { return seconds }
        // 英語: Xm Ys
        if let m = str.firstMatch(of: /(\d+)m/) { seconds += Int(m.1)! * 60 }
        if let s = str.firstMatch(of: /(\d+)s/) { seconds += Int(s.1)! }
        if seconds > 0 { return seconds }
        // 数字のみ（秒）
        if let raw = Int(str.trimmingCharacters(in: .whitespaces)) { return raw }
        return 0
    }
}
