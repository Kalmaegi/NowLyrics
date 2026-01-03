//
//  DesktopLyricsWindow.swift
//  NowLyrics
//
//  Created by Hans
//

import AppKit
import SnapKit

/// Lyrics background style enumeration
@MainActor
enum LyricsBackgroundStyle: String, CaseIterable, Sendable {
    case darkTranslucent = "dark_translucent"  // Black semi-transparent
    case blurEffect = "blur_effect"            // Frosted glass effect
    
    /// Display name for the style
    var displayName: String {
        switch self {
        case .darkTranslucent:
            return L10n.preferencesBackgroundDark
        case .blurEffect:
            return L10n.preferencesBackgroundBlur
        }
    }
    
    /// UserDefaults key
    static let userDefaultsKey = "lyrics_background_style"
    
    /// Get current saved style
    static var current: LyricsBackgroundStyle {
        if let savedValue = UserDefaults.standard.string(forKey: userDefaultsKey),
           let style = LyricsBackgroundStyle(rawValue: savedValue) {
            return style
        }
        return .darkTranslucent  // Default to dark translucent
    }
    
    /// Save style to UserDefaults
    func save() {
        UserDefaults.standard.set(self.rawValue, forKey: LyricsBackgroundStyle.userDefaultsKey)
        NotificationCenter.default.post(name: .lyricsBackgroundStyleDidChange, object: nil)
    }
}

/// Notification for background style changes
extension Notification.Name {
    static let lyricsBackgroundStyleDidChange = Notification.Name("com.nowlyrics.backgroundStyleDidChange")
}

/// Callback for when desktop lyrics window is closed
@MainActor
protocol DesktopLyricsWindowDelegate: AnyObject {
    func desktopLyricsDidClose()
}

/// Desktop lyrics window controller
class DesktopLyricsWindowController: NSWindowController {
    
    private let lyricsView: DesktopLyricsView
    private weak var lyricsManager: LyricsManager?
    weak var delegate: DesktopLyricsWindowDelegate?
    
    init(lyricsManager: LyricsManager) {
        self.lyricsManager = lyricsManager
        self.lyricsView = DesktopLyricsView()
        
        let window = NSWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: true
        )
        
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovableByWindowBackground = false
        
        super.init(window: window)
        
        setupWindow()
        setupObservers()
        
        // Set close callback for lyrics view
        lyricsView.onCloseButtonClicked = { [weak self] in
            self?.hideLyrics()
        }
        
        // Set resize callback for lyrics view
        lyricsView.onWindowResized = { [weak self] in
            self?.saveWindowFrame()
        }
        
        AppLogger.debug("Desktop lyrics window controller initialized", category: .ui)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        guard let window = window, let screen = NSScreen.main else { return }
        
        window.contentView = lyricsView
        
        // Apply current background style
        lyricsView.applyBackgroundStyle(LyricsBackgroundStyle.current)
        
        // Listen for background style changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(backgroundStyleChanged),
            name: .lyricsBackgroundStyleDidChange,
            object: nil
        )
        
        // Load saved window frame or use default
        let screenFrame = screen.visibleFrame
        let savedFrame = loadWindowFrame()
        
        AppLogger.debug("Screen frame: \(screenFrame)", category: .ui)
        AppLogger.debug("Saved window frame: \(String(describing: savedFrame))", category: .ui)
        
        // Check if saved frame intersects with screen (more lenient than contains)
        if let saved = savedFrame, screenFrame.intersects(saved) {
            AppLogger.info("Using saved window frame: \(saved)", category: .ui)
            window.setFrame(saved, display: true)
        } else {
            // Default size and position
            let windowWidth = min(screenFrame.width * 0.6, 800)
            let windowHeight: CGFloat = 100
            let windowX = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
            let windowY = screenFrame.origin.y + 50
            
            let defaultFrame = NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight)
            AppLogger.info("Using default window frame: \(defaultFrame)", category: .ui)
            window.setFrame(defaultFrame, display: true)
        }
    }
    
    /// Load saved window frame from UserDefaults
    private func loadWindowFrame() -> NSRect? {
        guard let frameString = UserDefaults.standard.string(forKey: "lyrics_window_frame") else {
            return nil
        }
        return NSRectFromString(frameString)
    }
    
    /// Save window frame to UserDefaults
    func saveWindowFrame() {
        guard let frame = window?.frame else { return }
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: "lyrics_window_frame")
    }
    
    private func setupObservers() {
        // Listen to screen changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc private func screenParametersChanged() {
        AppLogger.info("Screen parameters changed", category: .ui)
        
        // Only adjust window position if it's completely off-screen
        guard let window = window, let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        
        AppLogger.debug("Screen changed - screen: \(screenFrame), window: \(windowFrame)", category: .ui)
        
        // If window doesn't intersect with any screen, move it to main screen
        if !screenFrame.intersects(windowFrame) {
            AppLogger.warning("Window is off-screen, repositioning", category: .ui)
            let newX = screenFrame.origin.x + (screenFrame.width - windowFrame.width) / 2
            let newY = screenFrame.origin.y + 50
            let newFrame = NSRect(x: newX, y: newY, width: windowFrame.width, height: windowFrame.height)
            window.setFrame(newFrame, display: true)
            saveWindowFrame()
        }
    }
    
    @objc private func backgroundStyleChanged() {
        lyricsView.applyBackgroundStyle(LyricsBackgroundStyle.current)
        AppLogger.info("Background style changed to: \(LyricsBackgroundStyle.current.rawValue)", category: .ui)
    }
    
    func updateLyrics(currentLine: String?, nextLine: String?) {
        // Log window frame before update
        if let frame = window?.frame {
            AppLogger.debug("Window frame before lyrics update: \(frame)", category: .ui)
        }
        
        lyricsView.updateLyrics(currentLine: currentLine, nextLine: nextLine)
        
        // Log window frame after update
        if let frame = window?.frame {
            AppLogger.debug("Window frame after lyrics update: \(frame)", category: .ui)
        }
    }
    
    func setProgress(_ progress: Double) {
        lyricsView.setProgress(progress)
    }
    
    /// Show lyrics window
    func showLyrics() {
        window?.orderFront(nil)
        AppLogger.debug("Desktop lyrics shown", category: .ui)
    }
    
    /// Hide lyrics window
    func hideLyrics() {
        window?.orderOut(nil)
        delegate?.desktopLyricsDidClose()
        AppLogger.debug("Desktop lyrics hidden", category: .ui)
    }
    
    /// Check if lyrics window is visible
    var isLyricsVisible: Bool {
        return window?.isVisible ?? false
    }
}

/// Desktop lyrics view
class DesktopLyricsView: NSView {

    private let backgroundView: NSVisualEffectView
    private let darkBackgroundView: NSView
    private let stackView: NSStackView
    private let currentLyricsContainer: KaraokeLyricsContainer
    private let nextLineView: KaraokeLineView
    private let closeButton: NSButton
    private let resizeHandle: NSView
    
    /// Current background style
    private var currentStyle: LyricsBackgroundStyle = .darkTranslucent
    
    /// Callback when close button is clicked
    var onCloseButtonClicked: (() -> Void)?
    
    /// Callback when window is resized
    var onWindowResized: (() -> Void)?
    
    /// Track mouse inside state
    private var isMouseInside = false
    private var trackingArea: NSTrackingArea?
    
    /// Resize state
    private var isResizing = false
    private var resizeStartPoint: NSPoint = .zero
    private var resizeStartFrame: NSRect = .zero
    
    override init(frame frameRect: NSRect) {
        backgroundView = NSVisualEffectView()
        darkBackgroundView = NSView()
        stackView = NSStackView()
        currentLyricsContainer = KaraokeLyricsContainer()
        nextLineView = KaraokeLineView()
        closeButton = NSButton()
        resizeHandle = NSView()

        super.init(frame: frameRect)
        setupViews()
        setupTrackingArea()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        wantsLayer = true
        
        // Dark translucent background view (default)
        darkBackgroundView.wantsLayer = true
        darkBackgroundView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        darkBackgroundView.layer?.cornerRadius = 12
        darkBackgroundView.layer?.masksToBounds = true
        addSubview(darkBackgroundView)
        
        darkBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Blur effect background view (dark appearance for better contrast)
        backgroundView.material = .hudWindow
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.appearance = NSAppearance(named: .darkAqua)  // Force dark appearance
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 12
        backgroundView.layer?.masksToBounds = true
        backgroundView.isHidden = true  // Hidden by default
        addSubview(backgroundView)
        
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Stack view - add to main view, not background view
        stackView.orientation = .vertical
        stackView.spacing = 4
        stackView.alignment = .centerX
        addSubview(stackView)
        
        stackView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }
        
        // Current lyrics container (with karaoke effect)
        currentLyricsContainer.originalLineView.font = .systemFont(ofSize: 26, weight: .semibold)
        currentLyricsContainer.originalLineView.unhighlightedColor = .white
        currentLyricsContainer.originalLineView.highlightedColor = .systemCyan
        currentLyricsContainer.originalLineView.textAlignment = .center

        // Configure translation line style
        currentLyricsContainer.translationLineView.font = .systemFont(ofSize: 18, weight: .regular)
        currentLyricsContainer.translationLineView.unhighlightedColor = NSColor.white.withAlphaComponent(0.7)
        currentLyricsContainer.translationLineView.highlightedColor = .systemTeal
        currentLyricsContainer.translationLineView.textAlignment = .center

        // Apply shadow effect for better visibility
        currentLyricsContainer.renderStyle = .shadow(offset: NSSize(width: 0, height: -1), blur: 3)

        stackView.addArrangedSubview(currentLyricsContainer)

        // Next lyrics line (preview, with lighter color)
        nextLineView.font = .systemFont(ofSize: 16, weight: .medium)
        nextLineView.unhighlightedColor = NSColor.white.withAlphaComponent(0.6)
        nextLineView.highlightedColor = NSColor.white.withAlphaComponent(0.8)
        nextLineView.textAlignment = .center
        nextLineView.renderStyle = .shadow(offset: NSSize(width: 0, height: -1), blur: 2)
        stackView.addArrangedSubview(nextLineView)
        
        // Close button (initially hidden)
        closeButton.bezelStyle = .circular
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeButton.contentTintColor = NSColor.white.withAlphaComponent(0.8)
        closeButton.target = self
        closeButton.action = #selector(closeButtonClicked)
        closeButton.alphaValue = 0  // Initially hidden
        addSubview(closeButton)
        
        closeButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.equalToSuperview().offset(8)
            make.width.height.equalTo(20)
        }
        
        // Resize handle (bottom-right corner)
        resizeHandle.wantsLayer = true
        resizeHandle.alphaValue = 0  // Initially hidden
        addSubview(resizeHandle)
        
        resizeHandle.snp.makeConstraints { make in
            make.bottom.trailing.equalToSuperview()
            make.width.height.equalTo(16)
        }
        
        // Draw resize grip using CGMutablePath for compatibility
        let gripLayer = CAShapeLayer()
        let cgPath = CGMutablePath()
        // Draw three diagonal lines
        for i in 0..<3 {
            let offset = CGFloat(i) * 4 + 4
            cgPath.move(to: CGPoint(x: 16, y: offset))
            cgPath.addLine(to: CGPoint(x: offset, y: 16))
        }
        gripLayer.path = cgPath
        gripLayer.strokeColor = NSColor.white.withAlphaComponent(0.5).cgColor
        gripLayer.lineWidth = 1.5
        gripLayer.lineCap = .round
        resizeHandle.layer?.addSublayer(gripLayer)
    }
    
    private func setupTrackingArea() {
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        if let area = trackingArea {
            addTrackingArea(area)
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = trackingArea {
            removeTrackingArea(area)
        }
        setupTrackingArea()
    }
    
    override func mouseEntered(with event: NSEvent) {
        isMouseInside = true
        showControls()
    }
    
    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
        if !isResizing {
            hideControls()
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let resizeArea = NSRect(x: bounds.width - 20, y: 0, width: 20, height: 20)
        
        if resizeArea.contains(location) {
            isResizing = true
            resizeStartPoint = event.locationInWindow
            resizeStartFrame = window?.frame ?? .zero
            NSCursor.crosshair.push()  // Use crosshair as resize cursor
        } else {
            // Allow window dragging
            window?.performDrag(with: event)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isResizing, let window = window else { return }
        
        let currentPoint = event.locationInWindow
        let deltaX = currentPoint.x - resizeStartPoint.x
        let deltaY = currentPoint.y - resizeStartPoint.y
        
        // Calculate new frame (resize from bottom-right)
        var newFrame = resizeStartFrame
        newFrame.size.width = max(300, resizeStartFrame.width + deltaX)
        newFrame.size.height = max(80, resizeStartFrame.height - deltaY)
        newFrame.origin.y = resizeStartFrame.origin.y + resizeStartFrame.height - newFrame.height
        
        window.setFrame(newFrame, display: true)
    }
    
    override func mouseUp(with event: NSEvent) {
        if isResizing {
            isResizing = false
            NSCursor.pop()
            onWindowResized?()
            
            if !isMouseInside {
                hideControls()
            }
        }
    }
    
    private func showControls() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            closeButton.animator().alphaValue = 1
            resizeHandle.animator().alphaValue = 1
        }
    }
    
    private func hideControls() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            closeButton.animator().alphaValue = 0
            resizeHandle.animator().alphaValue = 0
        }
    }
    
    @objc private func closeButtonClicked() {
        AppLogger.info("Close button clicked on desktop lyrics", category: .ui)
        onCloseButtonClicked?()
    }
    
    /// Apply background style
    func applyBackgroundStyle(_ style: LyricsBackgroundStyle) {
        currentStyle = style
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            
            switch style {
            case .darkTranslucent:
                darkBackgroundView.animator().isHidden = false
                backgroundView.animator().isHidden = true
            case .blurEffect:
                darkBackgroundView.animator().isHidden = true
                backgroundView.animator().isHidden = false
            }
        }
        
        AppLogger.debug("Applied background style: \(style.rawValue)", category: .ui)
    }
    
    func updateLyrics(currentLine: String?, nextLine: String?) {
        // Log view bounds before update
        AppLogger.debug("DesktopLyricsView bounds before update: \(bounds), stackView frame: \(stackView.frame)", category: .ui)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true

            // Update current line (original text)
            currentLyricsContainer.setOriginalText(currentLine ?? "")

            // TODO: Update translation when available
            // For now, translation is hidden
            currentLyricsContainer.setTranslationText(nil)

            // Update next line preview
            nextLineView.setText(nextLine ?? "")

            // Hide/show view
            self.alphaValue = (currentLine?.isEmpty ?? true) && (nextLine?.isEmpty ?? true) ? 0 : 1
        }

        // Log view bounds after update
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            AppLogger.debug("DesktopLyricsView bounds after update: \(self.bounds), stackView frame: \(self.stackView.frame)", category: .ui)

            // Check if window frame changed
            if let window = self.window {
                AppLogger.debug("Window frame in async check: \(window.frame)", category: .ui)
            }
        }
    }

    func setProgress(_ progress: Double) {
        currentLyricsContainer.setProgress(progress)
        // Optionally update next line progress (could be disabled or use different progress)
        // nextLineView.setProgress(progress)
    }
}

