//
//  Routine_iosApp.swift
//  Routine-ios
//

import SwiftUI
import UserNotifications

@main
struct Routine_iosApp: App {
    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
