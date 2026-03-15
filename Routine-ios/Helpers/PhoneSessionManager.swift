//
//  PhoneSessionManager.swift
//  Routine-ios
//

import Foundation
import WatchConnectivity

@MainActor
class PhoneSessionManager: NSObject {
    static let shared = PhoneSessionManager()

    /// Watch から届いたコマンド（toggle / next / prev）を TimerViewModel へ転送するコールバック
    var onCommand: ((String) -> Void)?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Send

    func sendTimerState(
        routineName: String,
        taskName: String,
        taskIndex: Int,
        taskTotal: Int,
        taskEndDate: Date?,
        taskDuration: Int,
        isRunning: Bool,
        isFinished: Bool
    ) {
        guard WCSession.default.activationState == .activated else { return }

        let payload: [String: Any] = [
            WatchMessage.routineName:  routineName,
            WatchMessage.taskName:     taskName,
            WatchMessage.taskIndex:    taskIndex,
            WatchMessage.taskTotal:    taskTotal,
            WatchMessage.taskEndDate:  taskEndDate?.timeIntervalSince1970 ?? 0,
            WatchMessage.taskDuration: taskDuration,
            WatchMessage.isRunning:    isRunning,
            WatchMessage.isFinished:   isFinished,
            WatchMessage.sentAt:       Date().timeIntervalSince1970,
        ]

        // 常に applicationContext を更新（Watch 未接続時でも次回起動時に受け取れる）
        try? WCSession.default.updateApplicationContext(payload)

        // Watch が起きているときはリアルタイム送信
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil)
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneSessionManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // ペアリング切り替え後に再アクティベート
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let cmd = message[WatchMessage.cmdKey] as? String else { return }
        Task { @MainActor in
            self.onCommand?(cmd)
        }
    }
}
