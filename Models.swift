//
//  Models.swift
//  Routine-ios
//

import Foundation

// MARK: - App Language

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case ja
    case en
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .ja: return "日本語"
        case .en: return "English"
        }
    }
}

// MARK: - Routine Task

struct RoutineTask: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var duration: Int  // seconds
    
    func formattedDuration(lang: AppLanguage) -> String {
        let m = duration / 60
        let s = duration % 60
        
        if lang == .ja {
            if s == 0 {
                return "\(m)分"
            } else if m == 0 {
                return "\(s)秒"
            } else {
                return "\(m)分\(s)秒"
            }
        } else {
            if s == 0 {
                return "\(m)min"
            } else if m == 0 {
                return "\(s)sec"
            } else {
                return "\(m)min \(s)sec"
            }
        }
    }
}

// MARK: - Routine

struct Routine: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var tasks: [RoutineTask] = []
    
    var totalDuration: Int {
        tasks.reduce(0) { $0 + $1.duration }
    }
}
