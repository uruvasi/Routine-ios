//
//  WatchSessionManager.swift
//  Routine-watch
//

import Foundation
import WatchConnectivity

@MainActor @Observable
class WatchSessionManager: NSObject {

    // MARK: - State（Watch UI が観測する）

    var routineName: String = ""
    var taskName: String    = ""
    var taskIndex: Int      = 0
    var taskTotal: Int      = 0
    var taskDuration: Int   = 0
    var isRunning: Bool     = false
    var isFinished: Bool    = false
    var remaining: TimeInterval = 0

    private var taskEndDate: Date?
    private var timer: Timer?

    // MARK: - Computed

    var progress: Double {
        guard taskDuration > 0 else { return 0 }
        return 1.0 - remaining / TimeInterval(taskDuration)
    }

    var hasSession: Bool { taskTotal > 0 || isFinished }

    // MARK: - Init

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Commands → iPhone

    func sendCommand(_ cmd: String) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage([WatchMessage.cmdKey: cmd], replyHandler: nil)
    }

    // MARK: - Private

    private func apply(_ context: [String: Any]) {
        routineName  = context[WatchMessage.routineName]  as? String ?? ""
        taskName     = context[WatchMessage.taskName]     as? String ?? ""
        taskIndex    = context[WatchMessage.taskIndex]    as? Int    ?? 0
        taskTotal    = context[WatchMessage.taskTotal]    as? Int    ?? 0
        taskDuration = context[WatchMessage.taskDuration] as? Int    ?? 0
        isRunning    = context[WatchMessage.isRunning]    as? Bool   ?? false
        isFinished   = context[WatchMessage.isFinished]   as? Bool   ?? false

        // taskEndDate を復元（送受信の時刻ズレを sentAt で補正）
        let ts     = context[WatchMessage.taskEndDate] as? Double ?? 0
        let sentAt = context[WatchMessage.sentAt]      as? Double ?? Date().timeIntervalSince1970
        let lag    = Date().timeIntervalSince1970 - sentAt
        taskEndDate = ts > 0 ? Date(timeIntervalSince1970: ts + lag) : nil

        if isRunning, let end = taskEndDate {
            remaining = max(0, end.timeIntervalSinceNow)
            scheduleTimer()
        } else {
            timer?.invalidate()
            timer = nil
            remaining = isFinished ? 0 : TimeInterval(taskDuration)
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard isRunning, let end = taskEndDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        if remaining <= 0 {
            timer?.invalidate()
            timer = nil
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // 起動時に保存済みコンテキストがあれば適用
        let ctx = session.receivedApplicationContext
        if !ctx.isEmpty {
            Task { @MainActor in self.apply(ctx) }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.apply(message) }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in self.apply(applicationContext) }
    }
}
