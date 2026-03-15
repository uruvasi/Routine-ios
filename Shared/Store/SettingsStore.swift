import Foundation
import Combine

class SettingsStore: ObservableObject {
    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage_v1") }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "appLanguage_v1") ?? "ja"
        language = AppLanguage(rawValue: raw) ?? .ja
    }

    var l: L { L(lang: language) }
}
