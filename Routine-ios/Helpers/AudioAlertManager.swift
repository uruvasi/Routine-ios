//
//  AudioAlertManager.swift
//  Routine-ios
//

import AVFoundation

@MainActor
class AudioAlertManager {
    static let shared = AudioAlertManager()

    private let synthesizer = AVSpeechSynthesizer()
    private let engine = AVAudioEngine()

    /// トーン再生用
    private let toneNode = AVAudioPlayerNode()
    /// バックグラウンド維持用（無音ループ専用）
    private let silentNode = AVAudioPlayerNode()

    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

    /// SettingsStore の speechRate を反映する（RoutineTimerView が同期）
    var speechRate: Double = 1.0

    init() {
        // .playback カテゴリで消音スイッチを無視 + バックグラウンド再生を許可
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)

        engine.attach(toneNode)
        engine.attach(silentNode)
        engine.connect(toneNode,   to: engine.mainMixerNode, format: format)
        engine.connect(silentNode, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    // MARK: - 音声アラート

    /// タスク開始音（短い高音ビープ）
    func playStart() {
        playTone(frequency: 880, duration: 0.12)
    }

    /// タスク完了音（低めのビープ）
    func playEnd() {
        playTone(frequency: 660, duration: 0.35)
    }

    /// テキスト読み上げ
    func speak(_ text: String, lang: AppLanguage) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: lang == .ja ? "ja-JP" : "en-US")
        // speechRate は人間基準の倍率（1.0 = 標準速度）
        utterance.rate = Float(speechRate) * AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - バックグラウンド維持

    /// バックグラウンド移行時: 無音ループで AVAudioSession を維持し RunLoop を継続させる
    func startSilentLoop() {
        let frameCount = AVAudioFrameCount(44100) // 1秒の無音
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        // floatChannelData はゼロ初期化済み = 無音

        silentNode.stop()
        silentNode.scheduleBuffer(buffer, at: nil, options: .loops)
        silentNode.play()
    }

    /// フォアグラウンド復帰時: 無音ループを停止
    func stopSilentLoop() {
        silentNode.stop()
    }

    // MARK: - Private

    private func playTone(frequency: Double, duration: Double) {
        let sampleRate = 44100.0
        let frameCount = Int(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { return }
        buffer.frameLength = AVAudioFrameCount(frameCount)

        let data = buffer.floatChannelData![0]
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let fadeIn  = min(1.0, t / 0.01)
            let fadeOut = min(1.0, (duration - t) / 0.05)
            data[i] = Float(sin(2 * .pi * frequency * t) * 0.5 * fadeIn * fadeOut)
        }

        // toneNode は silentNode と独立しているので即時割り込み再生
        toneNode.stop()
        toneNode.scheduleBuffer(buffer)
        toneNode.play()
    }
}
