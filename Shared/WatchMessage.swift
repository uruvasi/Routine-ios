//
//  WatchMessage.swift
//  Shared
//

import Foundation

enum WatchMessage {
    // iPhone → Watch: context / message keys
    static let routineName  = "routineName"
    static let taskName     = "taskName"
    static let taskIndex    = "taskIndex"
    static let taskTotal    = "taskTotal"
    static let taskEndDate  = "taskEndDate"   // Double: timeIntervalSince1970、0 = nil
    static let taskDuration = "taskDuration"  // Int: 秒
    static let isRunning    = "isRunning"
    static let isFinished   = "isFinished"
    static let sentAt       = "sentAt"        // Double: 送信時刻（Watch 側で時刻ズレを補正）

    // Watch → iPhone: コマンド
    static let cmdKey    = "cmd"
    static let cmdToggle = "toggle"
    static let cmdNext   = "next"
    static let cmdPrev   = "prev"
}
