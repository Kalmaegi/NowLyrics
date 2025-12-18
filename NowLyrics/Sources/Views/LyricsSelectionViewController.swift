//
//  LyricsSelectionViewController.swift
//  NowLyrics
//
//  Created by Hans
//

import AppKit
import SnapKit

/// Lyrics selection view controller
class LyricsSelectionViewController: NSViewController {
    
    private let lyricsManager: LyricsManager
    
    private lazy var tableView: NSTableView = {
        let table = NSTableView()
        table.delegate = self
        table.dataSource = self
        table.headerView = nil
        table.rowHeight = 60
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .regular
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("LyricsColumn"))
        column.width = 400
        table.addTableColumn(column)
        
        return table
    }()
    
    private lazy var scrollView: NSScrollView = {
        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        return scroll
    }()
    
    private lazy var searchButton: NSButton = {
        let button = NSButton(title: "Search More Lyrics", target: self, action: #selector(searchMoreLyrics))
        button.bezelStyle = .rounded
        return button
    }()
    
    private lazy var previewTextView: NSTextView = {
        let textView = NSTextView()
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.5)
        return textView
    }()
    
    private lazy var previewScrollView: NSScrollView = {
        let scroll = NSScrollView()
        scroll.documentView = previewTextView
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        return scroll
    }()
    
    private lazy var applyButton: NSButton = {
        let button = NSButton(title: "Apply Selected Lyrics", target: self, action: #selector(applySelectedLyrics))
        button.bezelStyle = .rounded
        button.isEnabled = false
        return button
    }()
    
    private lazy var loadingIndicator: NSProgressIndicator = {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.isDisplayedWhenStopped = false
        return indicator
    }()
    
    init(lyricsManager: LyricsManager) {
        self.lyricsManager = lyricsManager
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupObservers()
    }
    
    private func setupViews() {
        view.addSubview(scrollView)
        view.addSubview(searchButton)
        view.addSubview(previewScrollView)
        view.addSubview(applyButton)
        view.addSubview(loadingIndicator)
        
        scrollView.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(16)
            make.width.equalTo(250)
            make.bottom.equalTo(searchButton.snp.top).offset(-8)
        }
        
        searchButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(16)
            make.width.equalTo(250)
        }
        
        previewScrollView.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(16)
            make.leading.equalTo(scrollView.snp.trailing).offset(16)
            make.bottom.equalTo(applyButton.snp.top).offset(-8)
        }
        
        applyButton.snp.makeConstraints { make in
            make.trailing.bottom.equalToSuperview().inset(16)
            make.width.equalTo(120)
        }
        
        loadingIndicator.snp.makeConstraints { make in
            make.centerY.equalTo(searchButton)
            make.leading.equalTo(searchButton.snp.trailing).offset(8)
        }
    }
    
    private func setupObservers() {
        // Observe lyrics list changes
        Task { @MainActor in
            for await _ in lyricsManager.availableLyricsStream {
                tableView.reloadData()
            }
        }
        
        Task { @MainActor in
            for await isSearching in lyricsManager.searchingStream {
                if isSearching {
                    loadingIndicator.startAnimation(nil)
                    searchButton.isEnabled = false
                } else {
                    loadingIndicator.stopAnimation(nil)
                    searchButton.isEnabled = true
                }
            }
        }
    }
    
    @objc private func searchMoreLyrics() {
        Task {
            await lyricsManager.searchMoreLyrics()
        }
    }
    
    @objc private func applySelectedLyrics() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < lyricsManager.availableLyrics.count else { return }
        
        let selectedLyrics = lyricsManager.availableLyrics[selectedRow]
        Task {
            await lyricsManager.selectLyrics(selectedLyrics)
            view.window?.close()
        }
    }
    
    private func updatePreview(for lyrics: Lyrics) {
        let preview = lyrics.lines.prefix(20).map { line in
            let timeString = formatTime(line.time)
            return "[\(timeString)] \(line.content)"
        }.joined(separator: "\n")
        
        previewTextView.string = preview
        if lyrics.lines.count > 20 {
            previewTextView.string += "\n\n... More lyrics ..."
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time - Double(Int(time))) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
}

// MARK: - NSTableViewDelegate & DataSource

extension LyricsSelectionViewController: NSTableViewDelegate, NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return lyricsManager.availableLyrics.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let lyrics = lyricsManager.availableLyrics[row]
        
        let cellView = LyricsCellView()
        cellView.configure(with: lyrics)
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        applyButton.isEnabled = selectedRow >= 0
        
        if selectedRow >= 0 && selectedRow < lyricsManager.availableLyrics.count {
            updatePreview(for: lyricsManager.availableLyrics[selectedRow])
        } else {
            previewTextView.string = ""
        }
    }
}

// MARK: - Lyrics Cell View

class LyricsCellView: NSView {
    
    private let titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    private let detailLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    private let badgeView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 4
        return view
    }()
    
    private let badgeLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 9, weight: .medium)
        label.textColor = .white
        return label
    }()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        addSubview(titleLabel)
        addSubview(detailLabel)
        addSubview(badgeView)
        badgeView.addSubview(badgeLabel)
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8)
            make.leading.equalToSuperview().inset(8)
            make.trailing.lessThanOrEqualTo(badgeView.snp.leading).offset(-8)
        }
        
        detailLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.equalToSuperview().inset(8)
            make.trailing.equalToSuperview().inset(8)
        }
        
        badgeView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(8)
            make.centerY.equalTo(titleLabel)
            make.height.equalTo(16)
        }
        
        badgeLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(NSEdgeInsets(top: 2, left: 6, bottom: 2, right: 6))
        }
    }
    
    func configure(with lyrics: Lyrics) {
        titleLabel.stringValue = "\(lyrics.title) - \(lyrics.artist)"
        
        var details: [String] = []
        details.append(lyrics.metadata.source.rawValue)
        details.append("\(lyrics.lines.count) lines")
        if lyrics.metadata.hasTranslation {
            details.append("Has translation")
        }
        detailLabel.stringValue = details.joined(separator: " · ")
        
        // Set badge
        if lyrics.metadata.isUserSelected {
            badgeLabel.stringValue = "Selected"
            badgeView.layer?.backgroundColor = NSColor.systemGreen.cgColor
            badgeView.isHidden = false
        } else if lyrics.metadata.quality > 80 {
            badgeLabel.stringValue = "High Match"
            badgeView.layer?.backgroundColor = NSColor.systemBlue.cgColor
            badgeView.isHidden = false
        } else {
            badgeView.isHidden = true
        }
    }
}
