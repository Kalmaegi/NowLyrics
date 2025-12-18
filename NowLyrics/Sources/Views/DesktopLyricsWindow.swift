//
//  DesktopLyricsWindow.swift
//  NowLyrics
//
//  Created by Hans
//

import AppKit
import SnapKit

/// Desktop lyrics window controller
class DesktopLyricsWindowController: NSWindowController {
    
    private let lyricsView: DesktopLyricsView
    private weak var lyricsManager: LyricsManager?
    
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
        print("launch finished")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        guard let window = window, let screen = NSScreen.main else { return }
        
        window.contentView = lyricsView
        
        // Set window size and position
        let screenFrame = screen.visibleFrame
        let windowWidth = screenFrame.width * 0.8
        let windowHeight: CGFloat = 120
        let windowX = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
        let windowY = screenFrame.origin.y + 50
        
        window.setFrame(NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight), display: true)
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
        setupWindow()
    }
    
    func updateLyrics(currentLine: String?, nextLine: String?) {
        lyricsView.updateLyrics(currentLine: currentLine, nextLine: nextLine)
    }
    
    func setProgress(_ progress: Double) {
        lyricsView.setProgress(progress)
    }
}

/// Desktop lyrics view
class DesktopLyricsView: NSView {
    
    private let backgroundView: NSVisualEffectView
    private let stackView: NSStackView
    private let currentLineLabel: KaraokeLabel
    private let nextLineLabel: NSTextField
    
    override init(frame frameRect: NSRect) {
        backgroundView = NSVisualEffectView()
        stackView = NSStackView()
        currentLineLabel = KaraokeLabel()
        nextLineLabel = NSTextField(labelWithString: "")
        
        super.init(frame: frameRect)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        wantsLayer = true
        
        // Background view
        backgroundView.material = .hudWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 12
        backgroundView.layer?.masksToBounds = true
        addSubview(backgroundView)
        
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Stack view
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.alignment = .centerX
        backgroundView.addSubview(stackView)
        
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
        
        // Current lyrics line
        currentLineLabel.font = .systemFont(ofSize: 28, weight: .medium)
        currentLineLabel.textColor = .white
        currentLineLabel.alignment = .center
        stackView.addArrangedSubview(currentLineLabel)
        
        // Next lyrics line
        nextLineLabel.font = .systemFont(ofSize: 18)
        nextLineLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        nextLineLabel.alignment = .center
        nextLineLabel.lineBreakMode = .byTruncatingTail
        stackView.addArrangedSubview(nextLineLabel)
    }
    
    func updateLyrics(currentLine: String?, nextLine: String?) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            
            currentLineLabel.stringValue = currentLine ?? ""
            nextLineLabel.stringValue = nextLine ?? ""
            
            // Hide/show view
            self.alphaValue = (currentLine?.isEmpty ?? true) && (nextLine?.isEmpty ?? true) ? 0 : 1
        }
    }
    
    func setProgress(_ progress: Double) {
        currentLineLabel.setProgress(progress)
    }
}

/// Karaoke effect label
class KaraokeLabel: NSTextField {
    
    private let progressLayer = CALayer()
    private var displayedProgress: Double = 0
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupProgressLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupProgressLayer()
    }
    
    private func setupProgressLayer() {
        wantsLayer = true
        isBezeled = false
        isEditable = false
        drawsBackground = false
        
        progressLayer.backgroundColor = NSColor.systemBlue.cgColor
        layer?.addSublayer(progressLayer)
    }
    
    func setProgress(_ progress: Double) {
        guard progress != displayedProgress else { return }
        displayedProgress = progress
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.05)
        
        let width = bounds.width * CGFloat(progress)
        progressLayer.frame = CGRect(x: 0, y: 0, width: width, height: bounds.height)
        
        CATransaction.commit()
    }
    
    override func layout() {
        super.layout()
        progressLayer.frame = CGRect(x: 0, y: 0, width: bounds.width * CGFloat(displayedProgress), height: bounds.height)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // Draw progress mask
        guard let context = NSGraphicsContext.current?.cgContext else {
            super.draw(dirtyRect)
            return
        }
        
        context.saveGState()
        
        // Draw non-highlighted part
        textColor = .white
        super.draw(dirtyRect)
        
        // Draw highlighted part
        let progressWidth = bounds.width * CGFloat(displayedProgress)
        let clipRect = NSRect(x: 0, y: 0, width: progressWidth, height: bounds.height)
        context.clip(to: clipRect)
        
        textColor = NSColor.systemCyan
        super.draw(dirtyRect)
        
        context.restoreGState()
        textColor = .white
    }
}
