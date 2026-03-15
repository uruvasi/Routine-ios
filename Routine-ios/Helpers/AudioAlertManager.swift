//
//  AudioAlertManager.swift
//  Routine-ios
//

import AVFoundation
import AudioToolbox

@MainActor
class AudioAlertManager {
    static let shared = AudioAlertManager()
    private let synthesizer = AVSpeechSynthesizer()

    /// タスク開始音（短いビープ）
    func playStart() {
        AudioServicesPlaySystemSound(1103) // Tock
    }

    /// タスク完了音（少し長めのビープ）
    func playEnd() {
        AudioServicesPlaySystemSound(1057) // Chime
    }

    /// テキスト読み上げ
    func speak(_ text: String, lang: AppLanguage) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: lang == .ja ? "ja-JP" : "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
