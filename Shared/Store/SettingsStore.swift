import Foundation

@Observable class SettingsStore {
    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage_v1") }
    }

    /// 読み上げ速度の倍率（0.5〜2.0、デフォルト 1.0）
    var speechRate: Double {
        didSet { UserDefaults.standard.set(speechRate, forKey: "speechRate_v1") }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "appLanguage_v1") ?? "ja"
        language = AppLanguage(rawValue: raw) ?? .ja
        let rate = UserDefaults.standard.double(forKey: "speechRate_v1")
        // 1.0 = 標準速度（AVSpeechUtteranceDefaultSpeechRate 基準）、範囲 1.0〜2.0
        speechRate = rate < 1.0 ? 1.0 : rate
    }

    var l: L { L(lang: language) }
}
