//
//  Routine_iosApp.swift
//  Routine-ios
//

import SwiftUI
import AlarmKit

@main
struct Routine_iosApp: App {
    init() {
        Task { try? await AlarmManager.shared.requestAuthorization() }
        _ = PhoneSessionManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
