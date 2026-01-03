//
//  KaraokeComponents.swift
//  NowLyrics
//
//  Created by Hans
//

import AppKit

// MARK: - Karaoke Render Style

/// Karaoke rendering style enumeration
enum KaraokeRenderStyle {
    case normal                                    // Basic color change
    case glow(radius: CGFloat, color: NSColor)    // Text with glow effect
    case stroke(width: CGFloat, color: NSColor)   // Text with stroke
    case shadow(offset: CGSize, blur: CGFloat)    // Text with shadow

    var description: String {
        switch self {
        case .normal: return "Normal"
        case .glow: return "Glow"
        case .stroke: return "Stroke"
        case .shadow: return "Shadow"
        }
    }
}

// MARK: - Karaoke Line View

/// Single line karaoke lyrics view with customizable rendering style
class KaraokeLineView: NSView {

    // MARK: - Properties

    private var text: String = ""
    private var progress: Double = 0.0

    /// Colors for non-highlighted and highlighted text
    var unhighlightedColor: NSColor = .white
    var highlightedColor: NSColor = .systemCyan

    /// Font for the lyrics text
    var font: NSFont = .systemFont(ofSize: 32, weight: .medium)

    /// Rendering style
    var renderStyle: KaraokeRenderStyle = .normal {
        didSet {
            needsDisplay = true
        }
    }

    /// Text alignment
    var textAlignment: NSTextAlignment = .center

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
    }

    // MARK: - Public Methods

    /// Update the displayed text
    func setText(_ text: String) {
        guard self.text != text else { return }
        self.text = text
        needsDisplay = true
    }

    /// Update the progress (0.0 - 1.0)
    func setProgress(_ progress: Double) {
        let clampedProgress = min(1.0, max(0.0, progress))
        guard abs(clampedProgress - self.progress) > 0.001 else { return }
        self.progress = clampedProgress
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard !text.isEmpty else { return }
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.saveGState()

        // Calculate text size and position
        let attributedString = createAttributedString(with: unhighlightedColor)
        let textSize = attributedString.size()
        let textRect = calculateTextRect(for: textSize)

        // Draw unhighlighted part
        drawText(attributedString, in: textRect, context: context)

        // Draw highlighted part with clipping
        if progress > 0 {
            let progressWidth = bounds.width * CGFloat(progress)
            let clipRect = NSRect(x: 0, y: 0, width: progressWidth, height: bounds.height)
            context.clip(to: clipRect)

            let highlightedAttributedString = createAttributedString(with: highlightedColor)
            drawText(highlightedAttributedString, in: textRect, context: context)
        }

        context.restoreGState()
    }

    // MARK: - Helper Methods

    private func createAttributedString(with color: NSColor) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        // Apply rendering style
        switch renderStyle {
        case .normal:
            break

        case .glow(let radius, let glowColor):
            let shadow = NSShadow()
            shadow.shadowColor = glowColor
            shadow.shadowBlurRadius = radius
            shadow.shadowOffset = .zero
            attributes[.shadow] = shadow

        case .stroke(let width, let strokeColor):
            attributes[.strokeColor] = strokeColor
            attributes[.strokeWidth] = -width

        case .shadow(let offset, let blur):
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
            shadow.shadowBlurRadius = blur
            shadow.shadowOffset = offset
            attributes[.shadow] = shadow
        }

        return NSAttributedString(string: text, attributes: attributes)
    }

    private func calculateTextRect(for textSize: CGSize) -> NSRect {
        let x: CGFloat
        switch textAlignment {
        case .left:
            x = 0
        case .right:
            x = bounds.width - textSize.width
        case .center, .justified, .natural:
            x = (bounds.width - textSize.width) / 2
        @unknown default:
            x = (bounds.width - textSize.width) / 2
        }

        let y = (bounds.height - textSize.height) / 2

        return NSRect(x: x, y: y, width: textSize.width, height: textSize.height)
    }

    private func drawText(_ attributedString: NSAttributedString, in rect: NSRect, context: CGContext) {
        attributedString.draw(in: rect)
    }

    // MARK: - Intrinsic Content Size

    override var intrinsicContentSize: NSSize {
        guard !text.isEmpty else {
            return NSSize(width: NSView.noIntrinsicMetric, height: 50)
        }

        let attributedString = createAttributedString(with: unhighlightedColor)
        let size = attributedString.size()
        return NSSize(width: size.width, height: max(size.height, 50))
    }
}

// MARK: - Karaoke Lyrics Container

/// Container view for managing multiple karaoke lines (original + translation)
class KaraokeLyricsContainer: NSView {

    // MARK: - Properties

    private let stackView: NSStackView

    /// Original line view (publicly accessible for configuration)
    let originalLineView: KaraokeLineView

    /// Translation line view (publicly accessible for configuration)
    let translationLineView: KaraokeLineView

    /// Whether to show translation
    var showTranslation: Bool = false {
        didSet {
            updateTranslationVisibility()
        }
    }

    /// Rendering style applied to both lines
    var renderStyle: KaraokeRenderStyle = .normal {
        didSet {
            originalLineView.renderStyle = renderStyle
            translationLineView.renderStyle = renderStyle
        }
    }

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        stackView = NSStackView()
        originalLineView = KaraokeLineView()
        translationLineView = KaraokeLineView()

        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        stackView = NSStackView()
        originalLineView = KaraokeLineView()
        translationLineView = KaraokeLineView()

        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        wantsLayer = true

        // Configure stack view
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)

        // Add constraints
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Configure original line view
        originalLineView.font = .systemFont(ofSize: 32, weight: .medium)
        stackView.addArrangedSubview(originalLineView)

        // Configure translation line view
        translationLineView.font = .systemFont(ofSize: 24, weight: .regular)
        translationLineView.unhighlightedColor = .lightGray
        translationLineView.highlightedColor = .systemTeal
        stackView.addArrangedSubview(translationLineView)

        updateTranslationVisibility()
    }

    // MARK: - Public Methods

    /// Update original line text
    func setOriginalText(_ text: String) {
        originalLineView.setText(text)
    }

    /// Update translation line text
    func setTranslationText(_ text: String?) {
        if let text = text, !text.isEmpty {
            translationLineView.setText(text)
            showTranslation = true
        } else {
            translationLineView.setText("")
            showTranslation = false
        }
    }

    /// Update progress for both lines
    func setProgress(_ progress: Double) {
        originalLineView.setProgress(progress)
        translationLineView.setProgress(progress)
    }

    // MARK: - Helper Methods

    private func updateTranslationVisibility() {
        translationLineView.isHidden = !showTranslation
    }
}
