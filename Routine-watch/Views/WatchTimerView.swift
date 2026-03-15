//
//  WatchTimerView.swift
//  Routine-watch
//

import SwiftUI

struct WatchTimerView: View {
    @Environment(WatchSessionManager.self) var sm

    var body: some View {
        VStack(spacing: 2) {
            Text("\(sm.taskIndex + 1) / \(sm.taskTotal)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(sm.taskName)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: sm.progress)
                    .stroke(Color.indigo, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: sm.progress)
                Text(timeString(sm.remaining))
                    .font(.system(size: 22, weight: .light, design: .monospaced))
                    .minimumScaleFactor(0.5)
            }
            .frame(width: 90, height: 90)

            HStack(spacing: 20) {
                Button {
                    sm.sendCommand(WatchMessage.cmdPrev)
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                }
                .disabled(sm.taskIndex == 0)
                .foregroundStyle(sm.taskIndex == 0 ? .secondary : .primary)
                .buttonStyle(.plain)

                Button {
                    sm.sendCommand(WatchMessage.cmdToggle)
                } label: {
                    Image(systemName: sm.isRunning ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(.indigo)
                }
                .buttonStyle(.plain)

                Button {
                    sm.sendCommand(WatchMessage.cmdNext)
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
                .foregroundStyle(.primary)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let total = Int(ceil(interval))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
