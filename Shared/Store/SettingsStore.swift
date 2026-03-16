import Foundation

@Observable class SettingsStore {
    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage_v1") }
    }

    var alarmBehavior: AlarmBehavior {
        didSet { UserDefaults.standard.set(alarmBehavior.rawValue, forKey: "alarmBehavior_v1") }
    }

    var startSoundPreset: StartSoundPreset {
        didSet { UserDefaults.standard.set(startSoundPreset.rawValue, forKey: "startSoundPreset_v1") }
    }

    init() {
        let rawLang = UserDefaults.standard.string(forKey: "appLanguage_v1") ?? "ja"
        language = AppLanguage(rawValue: rawLang) ?? .ja

        let rawAlarm = UserDefaults.standard.string(forKey: "alarmBehavior_v1") ?? AlarmBehavior.finalOnly.rawValue
        alarmBehavior = AlarmBehavior(rawValue: rawAlarm) ?? .finalOnly

        let rawSound = UserDefaults.standard.string(forKey: "startSoundPreset_v1") ?? StartSoundPreset.beep.rawValue
        startSoundPreset = StartSoundPreset(rawValue: rawSound) ?? .beep
    }

    var l: L { L(lang: language) }
}
