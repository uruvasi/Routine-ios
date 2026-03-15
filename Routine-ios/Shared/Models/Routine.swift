import Foundation

// NOTE: `Task` is reserved in Swift concurrency, so we use `RoutineTask`.

struct RoutineTask: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var duration: Int // seconds

    init(id: UUID = UUID(), name: String, duration: Int) {
        self.id = id
        self.name = name
        self.duration = duration
    }

    /// e.g. 90 → "1分30秒", 60 → "1分", 30 → "30秒"
    func formattedDuration(lang: AppLanguage = .ja) -> String {
        let m = duration / 60
        let s = duration % 60
        switch lang {
        case .ja:
            if m > 0 && s > 0 { return "\(m)分\(s)秒" }
            if m > 0           { return "\(m)分" }
            return "\(s)秒"
        case .en:
            if m > 0 && s > 0 { return "\(m)m \(s)s" }
            if m > 0           { return "\(m)m" }
            return "\(s)s"
        }
    }
}

struct Routine: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var tasks: [RoutineTask]

    init(id: UUID = UUID(), name: String, tasks: [RoutineTask] = []) {
        self.id = id
        self.name = name
        self.tasks = tasks
    }

    var totalDuration: Int {
        tasks.reduce(0) { $0 + $1.duration }
    }
}

enum AppLanguage: String, Codable, CaseIterable {
    case ja, en
}
