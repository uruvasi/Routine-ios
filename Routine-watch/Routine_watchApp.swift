//
//  Routine_watchApp.swift
//  Routine-watch
//

import SwiftUI

@main
struct Routine_watchApp: App {
    @State private var sessionManager = WatchSessionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sessionManager)
        }
    }
}
