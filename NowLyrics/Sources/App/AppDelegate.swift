//
//  AppDelegate.swift
//  NowLyrics
//
//  Created by Hans
//

import AppKit

@main
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusItem: NSStatusItem?
    private var lyricsManager: LyricsManager?
    private var desktopLyricsController: DesktopLyricsWindowController?
    private var lyricsSelectionWindow: NSWindow?
    private var preferencesWindowController: PreferencesWindowController?
    private var languageObserver: NSObjectProtocol?
    
    nonisolated static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLogger.info("launch started", category: .app)
        
        // Initialize localization manager
        _ = LocalizationManager.shared
        AppLogger.info("Localization manager initialized", category: .localization)
        
        setupStatusItem()
        setupLyricsManager()
        setupDesktopLyrics()
        setupLanguageObserver()
        
        AppLogger.info("Application launch completed", category: .app)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        AppLogger.info("Application will terminate", category: .app)
        
        // Remove language change observer
        if let observer = languageObserver {
            NotificationCenter.default.removeObserver(observer)
            AppLogger.debug("Language observer removed", category: .localization)
        }
        
        Task {
            await lyricsManager?.stop()
            AppLogger.debug("Lyrics manager stopped", category: .lyrics)
        }
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Setup
    
    private func setupStatusItem() {
        AppLogger.debug("Setting up status item", category: .ui)
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: "NowLyrics")
            AppLogger.debug("Status bar icon configured", category: .ui)
        } else {
            AppLogger.warning("Failed to set status bar icon", category: .ui)
        }
        
        rebuildMenu()
        AppLogger.info("Status item setup completed", category: .ui)
    }
    
    /// Rebuild menu (used to update menu text after language changes)
    private func rebuildMenu() {
        AppLogger.debug("Rebuilding status bar menu", category: .ui)
        
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: L10n.menuShowDesktopLyrics, action: #selector(toggleDesktopLyrics), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: L10n.menuSelectLyrics, action: #selector(showLyricsSelection), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.menuOffsetIncrease, action: #selector(increaseOffset), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: L10n.menuOffsetDecrease, action: #selector(decreaseOffset), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.menuSearchMore, action: #selector(searchMoreLyrics), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.menuPreferences, action: #selector(showPreferences), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.menuQuit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        
        statusItem?.menu = menu
        AppLogger.debug("Status bar menu rebuild completed", category: .ui)
    }
    
    /// Setup language change observer
    private func setupLanguageObserver() {
        AppLogger.debug("Setting up language change observer", category: .localization)
        
        languageObserver = NotificationCenter.default.addObserver(
            forName: .languageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            AppLogger.info("Language change notification received", category: .localization)
            Task { @MainActor [weak self] in
                self?.rebuildMenu()
                // Update lyrics selection window title if it's open
                if let window = self?.lyricsSelectionWindow {
                    window.title = L10n.lyricsSelectionTitle
                }
            }
        }
    }
    
    private func setupLyricsManager() {
        AppLogger.debug("Setting up lyrics manager", category: .lyrics)
        
        lyricsManager = LyricsManager()
        
        Task {
            guard let manager = lyricsManager else {
                AppLogger.error("Lyrics manager initialization failed", category: .lyrics)
                return
            }
            
            AppLogger.debug("Starting lyrics manager", category: .lyrics)
            await manager.start()
            observeLyricsChanges(manager: manager)
            AppLogger.info("Lyrics manager setup completed", category: .lyrics)
        }
    }
    
    private func observeLyricsChanges(manager: LyricsManager) {
        AppLogger.debug("Starting to observe lyrics changes", category: .lyrics)
        
        Task {
            for await _ in manager.lineIndexStream {
                updateDesktopLyrics()
            }
        }
    }
    
    private func setupDesktopLyrics() {
        AppLogger.debug("Setting up desktop lyrics", category: .ui)
        
        guard let manager = lyricsManager else {
            AppLogger.error("Lyrics manager not initialized, cannot setup desktop lyrics", category: .ui)
            return
        }
        
        desktopLyricsController = DesktopLyricsWindowController(lyricsManager: manager)
        desktopLyricsController?.showWindow(nil)
        AppLogger.info("Desktop lyrics setup completed", category: .ui)
    }
    
    private func updateDesktopLyrics() {
        guard let manager = lyricsManager,
              let lyrics = manager.currentLyrics else {
            desktopLyricsController?.updateLyrics(currentLine: nil, nextLine: nil)
            return
        }
        
        let currentLine = manager.currentLineIndex.flatMap { lyrics.lines[safe: $0]?.content }
        let nextLine = manager.currentLineIndex.flatMap { lyrics.lines[safe: $0 + 1]?.content }
        
        AppLogger.debug("Updating desktop lyrics: \(currentLine ?? "No lyrics")", category: .lyrics)
        desktopLyricsController?.updateLyrics(currentLine: currentLine, nextLine: nextLine)
    }
    
    // MARK: - Actions
    
    @objc private func toggleDesktopLyrics() {
        if let window = desktopLyricsController?.window {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                window.orderFront(nil)
            }
        }
    }
    
    @objc private func showLyricsSelection() {
        guard let manager = lyricsManager else { return }
        
        if lyricsSelectionWindow == nil {
            let viewController = LyricsSelectionViewController(lyricsManager: manager)
            let window = NSWindow(contentViewController: viewController)
            window.title = L10n.lyricsSelectionTitle
            window.styleMask = [.titled, .closable, .resizable]
            window.setContentSize(NSSize(width: 600, height: 400))
            window.center()
            lyricsSelectionWindow = window
        }
        
        lyricsSelectionWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func increaseOffset() {
        lyricsManager?.adjustOffset(by: 500)
    }
    
    @objc private func decreaseOffset() {
        lyricsManager?.adjustOffset(by: -500)
    }
    
    @objc private func searchMoreLyrics() {
        Task {
            await lyricsManager?.searchMoreLyrics()
        }
    }
    
    @objc private func showPreferences() {
        AppLogger.info("User clicked preferences", category: .ui)
        
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
        }
        
        preferencesWindowController?.showWindow(nil)
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
