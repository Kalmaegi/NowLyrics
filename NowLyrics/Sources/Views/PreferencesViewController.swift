//
//  PreferencesViewController.swift
//  NowLyrics
//
//  Created by Hans
//

import AppKit

class PreferencesViewController: NSViewController {
    
    // MARK: - UI Components
    
    private lazy var backgroundStyleLabel: NSTextField = {
        let label = NSTextField(labelWithString: L10n.preferencesBackgroundStyle)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        return label
    }()
    
    private lazy var backgroundStylePopUpButton: NSPopUpButton = {
        let button = NSPopUpButton()
        button.target = self
        button.action = #selector(backgroundStyleChanged(_:))
        return button
    }()
    
    private lazy var languageLabel: NSTextField = {
        let label = NSTextField(labelWithString: L10n.preferencesLanguage)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        return label
    }()
    
    private lazy var languagePopUpButton: NSPopUpButton = {
        let button = NSPopUpButton()
        button.target = self
        button.action = #selector(languageChanged(_:))
        return button
    }()
    
    private lazy var versionLabel: NSTextField = {
        let versionString = getVersionString()
        let label = NSTextField(labelWithString: versionString)
        label.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        label.textColor = NSColor.secondaryLabelColor
        label.alignment = .center
        return label
    }()
    
    private lazy var separatorView: NSBox = {
        let box = NSBox()
        box.boxType = .separator
        return box
    }()
    
    private lazy var titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: L10n.preferencesTitle)
        label.font = NSFont.boldSystemFont(ofSize: 16)
        label.textColor = NSColor.labelColor
        label.alignment = .center
        return label
    }()
    
    private lazy var aboutLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Modern lyrics display application for macOS")
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = NSColor.secondaryLabelColor
        label.alignment = .center
        return label
    }()
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 280))
        view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        AppLogger.debug("Preferences view loaded", category: .ui)
        
        setupUI()
        setupBackgroundStyleOptions()
        setupLanguageOptions()
        setupLanguageObserver()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Add all views
        [titleLabel, aboutLabel, backgroundStyleLabel, backgroundStylePopUpButton,
         languageLabel, languagePopUpButton, separatorView, versionLabel].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            // Title label
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 25),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // About label
            aboutLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            aboutLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Background style label
            backgroundStyleLabel.topAnchor.constraint(equalTo: aboutLabel.bottomAnchor, constant: 30),
            backgroundStyleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // Background style selection button
            backgroundStylePopUpButton.centerYAnchor.constraint(equalTo: backgroundStyleLabel.centerYAnchor),
            backgroundStylePopUpButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            backgroundStylePopUpButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            
            // Language label
            languageLabel.topAnchor.constraint(equalTo: backgroundStyleLabel.bottomAnchor, constant: 20),
            languageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // Language selection button
            languagePopUpButton.centerYAnchor.constraint(equalTo: languageLabel.centerYAnchor),
            languagePopUpButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            languagePopUpButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            
            // Separator
            separatorView.topAnchor.constraint(equalTo: languageLabel.bottomAnchor, constant: 25),
            separatorView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            separatorView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            separatorView.heightAnchor.constraint(equalToConstant: 1),
            
            // Version label
            versionLabel.topAnchor.constraint(equalTo: separatorView.bottomAnchor, constant: 20),
            versionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            versionLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -25)
        ])
        
        AppLogger.debug("Preferences interface layout completed", category: .ui)
    }
    
    private func setupBackgroundStyleOptions() {
        backgroundStylePopUpButton.removeAllItems()
        
        // Add all background style options
        for style in LyricsBackgroundStyle.allCases {
            backgroundStylePopUpButton.addItem(withTitle: style.displayName)
            backgroundStylePopUpButton.lastItem?.representedObject = style
        }
        
        // Select current style
        updateSelectedBackgroundStyle()
        
        AppLogger.debug("Background style options setup completed", category: .ui)
    }
    
    private func updateSelectedBackgroundStyle() {
        let currentStyle = LyricsBackgroundStyle.current
        
        for item in backgroundStylePopUpButton.itemArray {
            if let style = item.representedObject as? LyricsBackgroundStyle,
               style == currentStyle {
                backgroundStylePopUpButton.select(item)
                break
            }
        }
    }
    
    private func setupLanguageOptions() {
        languagePopUpButton.removeAllItems()
        
        // Add all supported language options
        for language in AppLanguage.allCases {
            let title = language == .system 
                ? "\(language.displayName) (\(LocalizationManager.shared.systemLanguageDisplayName))"
                : language.displayName
            languagePopUpButton.addItem(withTitle: title)
            languagePopUpButton.lastItem?.representedObject = language
        }
        
        // Select current language
        updateSelectedLanguage()
        
        AppLogger.debug("Language options setup completed", category: .localization)
    }
    
    private func updateSelectedLanguage() {
        let currentLanguage = LocalizationManager.shared.currentLanguage
        
        for item in languagePopUpButton.itemArray {
            if let language = item.representedObject as? AppLanguage,
               language == currentLanguage {
                languagePopUpButton.select(item)
                break
            }
        }
    }
    
    private func setupLanguageObserver() {
        Task { @MainActor in
            for await language in LocalizationManager.shared.languageStream {
                AppLogger.debug("Preferences page received language change: \(language)", category: .localization)
                updateUIForLanguageChange()
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func backgroundStyleChanged(_ sender: NSPopUpButton) {
        guard let selectedItem = sender.selectedItem,
              let style = selectedItem.representedObject as? LyricsBackgroundStyle else {
            AppLogger.warning("Unable to get selected background style", category: .ui)
            return
        }
        
        AppLogger.info("User selected background style: \(style.rawValue)", category: .ui)
        style.save()
    }
    
    @objc private func languageChanged(_ sender: NSPopUpButton) {
        guard let selectedItem = sender.selectedItem,
              let language = selectedItem.representedObject as? AppLanguage else {
            AppLogger.warning("Unable to get selected language", category: .localization)
            return
        }
        
        AppLogger.info("User selected language: \(language.rawValue)", category: .localization)
        LocalizationManager.shared.setLanguage(language)
    }
    
    // MARK: - Language Update
    
    private func updateUIForLanguageChange() {
        // Update label text
        titleLabel.stringValue = L10n.preferencesTitle
        backgroundStyleLabel.stringValue = L10n.preferencesBackgroundStyle
        languageLabel.stringValue = L10n.preferencesLanguage
        
        // Reset options (update display text)
        setupBackgroundStyleOptions()
        setupLanguageOptions()
        
        // Update window title (if needed)
        view.window?.title = L10n.preferencesTitle
        
        AppLogger.debug("Preferences interface language update completed", category: .ui)
    }
    
    // MARK: - Utilities
    
    private func getVersionString() -> String {
        guard let infoDictionary = Bundle.main.infoDictionary,
              let version = infoDictionary["CFBundleShortVersionString"] as? String,
              let build = infoDictionary["CFBundleVersion"] as? String else {
            return "NowLyrics v1.0.0"
        }
        
        return "NowLyrics v\(version) (\(build))"
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Window Controller

class PreferencesWindowController: NSWindowController {
    
    convenience init() {
        let viewController = PreferencesViewController()
        let window = NSWindow(contentViewController: viewController)
        
        window.title = L10n.preferencesTitle
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 480, height: 280))
        window.minSize = NSSize(width: 420, height: 240)
        window.maxSize = NSSize(width: 600, height: 400)
        window.center()
        window.isReleasedWhenClosed = false
        
        self.init(window: window)
        
        AppLogger.debug("Preferences window created", category: .ui)
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        AppLogger.info("Show preferences window", category: .ui)
    }
}
