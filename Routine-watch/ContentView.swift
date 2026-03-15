//
//  ContentView.swift
//  Routine-watch
//

import SwiftUI

struct ContentView: View {
    @Environment(WatchSessionManager.self) var sessionManager

    var body: some View {
        Group {
            if sessionManager.isFinished {
                finishedView
            } else if sessionManager.hasSession {
                WatchTimerView()
            } else {
                idleView
            }
        }
    }

    private var idleView: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("iPhone でタイマーを開始してください")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var finishedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text("完了！")
                .font(.headline)
            if !sessionManager.routineName.isEmpty {
                Text(sessionManager.routineName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
