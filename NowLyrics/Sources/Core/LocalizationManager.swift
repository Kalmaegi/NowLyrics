//
//  LocalizationManager.swift
//  NowLyrics
//
//  Created by Hans
//

import Foundation

/// Supported language enumeration
enum AppLanguage: String, CaseIterable, Sendable {
    case system = "system"      // Follow system
    case english = "en"         // English
    case chinese = "zh-Hans"    // Simplified Chinese
    
    /// Display name for the language
    var displayName: String {
        switch self {
        case .system:
            return "Follow System"  // Avoid circular dependency, use direct string
        case .english:
            return "English"
        case .chinese:
            return "简体中文"
        }
    }
    
    /// Get actual language code (resolve system option)
    var resolvedLanguageCode: String {
        switch self {
        case .system:
            return LocalizationManager.systemPreferredLanguageCode
        case .english, .chinese:
            return self.rawValue
        }
    }
}

/// Localization Manager
///
/// Usage:
/// 1. Get localized string: `L10n.menuShowDesktopLyrics`
/// 2. Switch language: `LocalizationManager.shared.setLanguage(.chinese)`
/// 3. Get current language: `LocalizationManager.shared.currentLanguage`
final class LocalizationManager {
    
    // MARK: - Singleton
    
    @MainActor static let shared = LocalizationManager()
    
    // MARK: - Properties
    
    /// Currently selected language
    private(set) var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: Keys.appLanguage)
            updateBundle()
            Task { @MainActor in
                NotificationCenter.default.post(name: .languageDidChange, object: nil)
            }
            languageContinuation.yield(currentLanguage)
        }
    }
    
    /// Current localization bundle in use
    private(set) var bundle: Bundle = .main
    
    /// AsyncStream for language changes
    let languageStream: AsyncStream<AppLanguage>
    private let languageContinuation: AsyncStream<AppLanguage>.Continuation
    
    /// System preferred language code (static method to avoid circular dependency)
    static var systemPreferredLanguageCode: String {
        // Locale.preferredLanguages returns user's language preference list
        // Example: ["zh-Hans-CN", "en-US", "ja-JP"]
        let preferredLanguages = Locale.preferredLanguages
        
        // Check if user's preferred language includes Chinese
        for language in preferredLanguages {
            if language.hasPrefix("zh-Hans") || language.hasPrefix("zh-CN") {
                return "zh-Hans"
            }
            if language.hasPrefix("en") {
                return "en"
            }
        }
        
        // Default to English
        return "en"
    }
    
    /// System preferred language code (instance method)
    var systemPreferredLanguageCode: String {
        LocalizationManager.systemPreferredLanguageCode
    }
    
    /// Display name for system preferred language
    var systemLanguageDisplayName: String {
        let code = systemPreferredLanguageCode
        switch code {
        case "zh-Hans":
            return "简体中文"
        default:
            return "English"
        }
    }
    
    // MARK: - Constants
    
    private enum Keys {
        static let appLanguage = "app_language"
    }
    
    // MARK: - Initialization
    
    private init() {
        // Initialize AsyncStream
        (languageStream, languageContinuation) = AsyncStream.makeStream(of: AppLanguage.self)
        
        // Read saved language setting from UserDefaults
        if let savedLanguage = UserDefaults.standard.string(forKey: Keys.appLanguage),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            // First install, default to follow system
            self.currentLanguage = .system
        }
        
        updateBundle()
        
        // Send initial value to stream
        languageContinuation.yield(currentLanguage)
    }
    
    deinit {
        languageContinuation.finish()
    }
    
    // MARK: - Public Methods
    
    /// Set application language
    /// - Parameter language: Target language
    @MainActor
    func setLanguage(_ language: AppLanguage) {
        guard language != currentLanguage else { return }
        currentLanguage = language
    }
    
    /// Get localized string
    /// - Parameters:
    ///   - key: Localization key
    ///   - arguments: Format arguments
    /// - Returns: Localized string
    func localizedString(_ key: String, arguments: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: nil, table: nil)
        if arguments.isEmpty {
            return format
        }
        return String(format: format, arguments: arguments)
    }
    
    // MARK: - Private Methods
    
    /// Update localization bundle
    private func updateBundle() {
        let languageCode = currentLanguage.resolvedLanguageCode
        
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.bundle = bundle
        } else {
            // If no corresponding language bundle found, use main bundle
            self.bundle = .main
        }
    }
}


extension Notification.Name {
    /// Language change notification
    static let languageDidChange = Notification.Name("com.nowlyrics.languageDidChange")
}


/// Localized string shortcut access
///
/// Usage example:
/// ```swift
/// label.text = L10n.menuShowDesktopLyrics
/// ```
enum L10n {
    
    // MARK: - Menu Items
    
    @MainActor static var menuShowDesktopLyrics: String {
        LocalizationManager.shared.localizedString("menu.show_desktop_lyrics")
    }
    
    @MainActor static var menuHideDesktopLyrics: String {
        LocalizationManager.shared.localizedString("menu.hide_desktop_lyrics")
    }
    
    @MainActor static var menuSelectLyrics: String {
        LocalizationManager.shared.localizedString("menu.select_lyrics")
    }
    
    @MainActor static var menuOffsetIncrease: String {
        LocalizationManager.shared.localizedString("menu.offset_increase")
    }
    
    @MainActor static var menuOffsetDecrease: String {
        LocalizationManager.shared.localizedString("menu.offset_decrease")
    }
    
    @MainActor static var menuSearchMore: String {
        LocalizationManager.shared.localizedString("menu.search_more")
    }
    
    @MainActor static var menuPreferences: String {
        LocalizationManager.shared.localizedString("menu.preferences")
    }
    
    @MainActor static var menuQuit: String {
        LocalizationManager.shared.localizedString("menu.quit")
    }
    
    // MARK: - Lyrics Selection
    
    @MainActor static var lyricsSelectionTitle: String {
        LocalizationManager.shared.localizedString("lyrics_selection.title")
    }
    
    @MainActor static var lyricsSelectionSearchPlaceholder: String {
        LocalizationManager.shared.localizedString("lyrics_selection.search_placeholder")
    }
    
    @MainActor static var lyricsSelectionNoResults: String {
        LocalizationManager.shared.localizedString("lyrics_selection.no_results")
    }
    
    @MainActor static var lyricsSelectionLoading: String {
        LocalizationManager.shared.localizedString("lyrics_selection.loading")
    }
    
    @MainActor static var lyricsSelectionSelect: String {
        LocalizationManager.shared.localizedString("lyrics_selection.select")
    }
    
    @MainActor static var lyricsSelectionCancel: String {
        LocalizationManager.shared.localizedString("lyrics_selection.cancel")
    }
    
    // MARK: - Desktop Lyrics
    
    @MainActor static var desktopLyricsNoLyrics: String {
        LocalizationManager.shared.localizedString("desktop_lyrics.no_lyrics")
    }
    
    @MainActor static var desktopLyricsNoMusic: String {
        LocalizationManager.shared.localizedString("desktop_lyrics.no_music")
    }
    
    // MARK: - Preferences
    
    @MainActor static var preferencesTitle: String {
        LocalizationManager.shared.localizedString("preferences.title")
    }
    
    @MainActor static var preferencesGeneral: String {
        LocalizationManager.shared.localizedString("preferences.general")
    }
    
    @MainActor static var preferencesAppearance: String {
        LocalizationManager.shared.localizedString("preferences.appearance")
    }
    
    @MainActor static var preferencesLanguage: String {
        LocalizationManager.shared.localizedString("preferences.language")
    }
    
    @MainActor static var preferencesLanguageSystem: String {
        LocalizationManager.shared.localizedString("preferences.language.system")
    }
    
    @MainActor static var preferencesLanguageEnglish: String {
        LocalizationManager.shared.localizedString("preferences.language.english")
    }
    
    @MainActor static var preferencesLanguageChinese: String {
        LocalizationManager.shared.localizedString("preferences.language.chinese")
    }
    
    // MARK: - Notifications
    
    @MainActor static var notificationLyricsFound: String {
        LocalizationManager.shared.localizedString("notification.lyrics_found")
    }
    
    @MainActor static var notificationLyricsNotFound: String {
        LocalizationManager.shared.localizedString("notification.lyrics_not_found")
    }
    
    @MainActor static func notificationOffsetAdjusted(_ seconds: String) -> String {
        LocalizationManager.shared.localizedString("notification.offset_adjusted", arguments: seconds)
    }
    
    // MARK: - Errors
    
    @MainActor static var errorAppleMusicAccess: String {
        LocalizationManager.shared.localizedString("error.apple_music_access")
    }
    
    @MainActor static var errorNetwork: String {
        LocalizationManager.shared.localizedString("error.network")
    }
    
    @MainActor static var errorLyricsParse: String {
        LocalizationManager.shared.localizedString("error.lyrics_parse")
    }
    
    // MARK: - General
    
    @MainActor static var generalOK: String {
        LocalizationManager.shared.localizedString("general.ok")
    }
    
    @MainActor static var generalCancel: String {
        LocalizationManager.shared.localizedString("general.cancel")
    }
    
    @MainActor static var generalSave: String {
        LocalizationManager.shared.localizedString("general.save")
    }
    
    @MainActor static var generalClose: String {
        LocalizationManager.shared.localizedString("general.close")
    }
}
