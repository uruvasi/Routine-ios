//
//  AudioAlertManager.swift
//  Routine-ios
//

import AVFoundation

@MainActor
class AudioAlertManager {
    static let shared = AudioAlertManager()

    private let engine = AVAudioEngine()

    /// トーン再生用
    private let toneNode = AVAudioPlayerNode()
    /// バックグラウンド維持用（無音ループ専用）
    private let silentNode = AVAudioPlayerNode()

    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

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

    /// タスク開始音（プリセット選択可）
    func playStart(preset: StartSoundPreset = .beep) {
        switch preset {
        case .beep:   playTone(frequency: 880,  duration: 0.12)
        case .soft:   playTone(frequency: 660,  duration: 0.18)
        case .high:   playTone(frequency: 1047, duration: 0.10)
        case .double: playDoubleTone(frequency: 880, toneDuration: 0.10, gap: 0.08)
        case .off:    break
        }
    }

    /// タスク完了音（低めのビープ）
    func playEnd() {
        playTone(frequency: 660, duration: 0.35)
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

    private func playDoubleTone(frequency: Double, toneDuration: Double, gap: Double) {
        let sampleRate = 44100.0
        let toneFrames = Int(sampleRate * toneDuration)
        let gapFrames  = Int(sampleRate * gap)
        let total      = toneFrames * 2 + gapFrames
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(total)) else { return }
        buffer.frameLength = AVAudioFrameCount(total)
        let data = buffer.floatChannelData![0]
        for i in 0..<total {
            if i < toneFrames {
                let t = Double(i) / sampleRate
                let fadeIn  = min(1.0, t / 0.01)
                let fadeOut = min(1.0, (toneDuration - t) / 0.05)
                data[i] = Float(sin(2 * .pi * frequency * t) * 0.5 * fadeIn * fadeOut)
            } else if i < toneFrames + gapFrames {
                data[i] = 0
            } else {
                let t = Double(i - toneFrames - gapFrames) / sampleRate
                let fadeIn  = min(1.0, t / 0.01)
                let fadeOut = min(1.0, (toneDuration - t) / 0.05)
                data[i] = Float(sin(2 * .pi * frequency * t) * 0.5 * fadeIn * fadeOut)
            }
        }
        toneNode.stop()
        toneNode.scheduleBuffer(buffer)
        toneNode.play()
    }

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
