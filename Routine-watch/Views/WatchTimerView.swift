//
//  WatchTimerView.swift
//  Routine-watch
//

import SwiftUI

struct WatchTimerView: View {
    @Environment(WatchSessionManager.self) var sm

    var body: some View {
        VStack(spacing: 0) {

            // ── 上段: タスク名（左）+ 一時停止/再生（右上） ──
            HStack(alignment: .top) {
                Text(sm.taskName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    sm.sendCommand(WatchMessage.cmdToggle)
                } label: {
                    Image(systemName: sm.isRunning ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(sm.isRunning ? .yellow : .green)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // ── 中央: 残り時間（大） ──
            Text(timeString(sm.remaining))
                .font(.system(size: 52, weight: .semibold, design: .monospaced))
                .minimumScaleFactor(0.4)
                .lineLimit(1)

            Spacer()

            // ── 下段: 前へ（左）+ 次へ（右） ──
            HStack {
                Button {
                    sm.sendCommand(WatchMessage.cmdPrev)
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundStyle(sm.taskIndex == 0 ? .secondary : .primary)
                        .frame(width: 54, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(sm.taskIndex == 0)

                Spacer()

                Button {
                    sm.sendCommand(WatchMessage.cmdNext)
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .frame(width: 54, height: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let total = Int(ceil(interval))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
