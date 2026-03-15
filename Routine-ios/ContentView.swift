//
//  ContentView.swift
//  Routine-ios
//

import SwiftUI

struct ContentView: View {
    @State private var routineStore = RoutineStore()
    @State private var settingsStore = SettingsStore()

    var body: some View {
        TabView {
            NavigationStack {
                RoutineListView()
            }
            .tabItem {
                Label(settingsStore.l.routinesTab, systemImage: "list.bullet.clipboard")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(settingsStore.l.settingsTab, systemImage: "gearshape")
            }
        }
        .environment(routineStore)
        .environment(settingsStore)
    }
}
