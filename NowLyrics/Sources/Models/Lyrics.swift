//
//  Lyrics.swift
//  NowLyrics
//
//  Created by Hans
//

import Foundation

/// Lyrics line containing timestamp and lyrics content
struct LyricsLine: Equatable, Hashable, Sendable {
    /// Line start time (seconds)
    let time: TimeInterval
    /// Lyrics content
    let content: String
    /// Translation content (if available)
    let translation: String?
    /// Word-by-word time tags (for karaoke effect)
    let timetags: [WordTimetag]?
    
    init(time: TimeInterval, content: String, translation: String? = nil, timetags: [WordTimetag]? = nil) {
        self.time = time
        self.content = content
        self.translation = translation
        self.timetags = timetags
    }
}

/// Word-by-word time tag
struct WordTimetag: Equatable, Hashable, Sendable {
    /// Time offset relative to line start (seconds)
    let timeOffset: TimeInterval
    /// Character index position
    let index: Int
}

/// Lyrics source enumeration
enum LyricsSource: String, Codable, Sendable {
    case netease = "NetEase Music"
    case qqMusic = "QQ Music"
    case kugou = "Kugou Music"
    case genius = "Genius"
    case local = "Local"
    case manual = "Manual Import"
    case unknown = "Unknown"
}

/// Lyrics metadata
struct LyricsMetadata: Equatable, Hashable, Sendable, Codable {
    /// Lyrics source
    var source: LyricsSource
    /// Original ID from lyrics source
    var sourceID: String?
    /// Lyrics quality score (0-100)
    var quality: Int
    /// Whether contains translation
    var hasTranslation: Bool
    /// Whether contains word-by-word time tags
    var hasTimetags: Bool
    /// Lyrics language
    var language: String?
    /// User manually selected flag
    var isUserSelected: Bool
    /// Download time
    var downloadedAt: Date?
    
    init(
        source: LyricsSource = .unknown,
        sourceID: String? = nil,
        quality: Int = 0,
        hasTranslation: Bool = false,
        hasTimetags: Bool = false,
        language: String? = nil,
        isUserSelected: Bool = false,
        downloadedAt: Date? = nil
    ) {
        self.source = source
        self.sourceID = sourceID
        self.quality = quality
        self.hasTranslation = hasTranslation
        self.hasTimetags = hasTimetags
        self.language = language
        self.isUserSelected = isUserSelected
        self.downloadedAt = downloadedAt
    }
}

/// Complete lyrics object
struct Lyrics: Equatable, Hashable, Sendable {
    /// Unique identifier
    let id: UUID
    /// Associated track ID
    let trackID: String
    /// Song title
    var title: String
    /// Artist name
    var artist: String
    /// Lyrics metadata
    var metadata: LyricsMetadata
    /// Lyrics lines array
    var lines: [LyricsLine]
    /// Time offset (milliseconds)
    var offset: Int
    
    init(
        id: UUID = UUID(),
        trackID: String,
        title: String,
        artist: String,
        metadata: LyricsMetadata = LyricsMetadata(),
        lines: [LyricsLine] = [],
        offset: Int = 0
    ) {
        self.id = id
        self.trackID = trackID
        self.title = title
        self.artist = artist
        self.metadata = metadata
        self.lines = lines
        self.offset = offset
    }
    
    /// Time offset (seconds)
    var offsetInSeconds: TimeInterval {
        TimeInterval(offset) / 1000.0
    }
    
    /// Get current lyrics line index based on playback time
    func lineIndex(at time: TimeInterval) -> Int? {
        let adjustedTime = time + offsetInSeconds
        guard !lines.isEmpty else { return nil }
        
        // Use binary search to find the current lyrics line to display
        var left = 0
        var right = lines.count - 1
        var result: Int?
        
        while left <= right {
            let mid = (left + right) / 2
            if lines[mid].time <= adjustedTime {
                result = mid
                left = mid + 1
            } else {
                right = mid - 1
            }
        }
        
        return result
    }
    
    /// Get current lyrics line
    func currentLine(at time: TimeInterval) -> LyricsLine? {
        guard let index = lineIndex(at: time) else { return nil }
        return lines[index]
    }
    
    /// Get next lyrics line
    func nextLine(at time: TimeInterval) -> LyricsLine? {
        guard let currentIndex = lineIndex(at: time),
              currentIndex + 1 < lines.count else { return nil }
        return lines[currentIndex + 1]
    }
}

// MARK: - LRC Parsing

extension Lyrics {
    /// Parse lyrics from LRC format string
    static func parse(lrcContent: String, trackID: String, metadata: LyricsMetadata = LyricsMetadata()) -> Lyrics? {
        var title = ""
        var artist = ""
        var offset = 0
        var lines: [LyricsLine] = []
        
        let pattern = #"\[(\d{2}):(\d{2})\.(\d{2,3})\](.+)"#
        let metaPatterns = [
            "ti": #"\[ti:(.+)\]"#,
            "ar": #"\[ar:(.+)\]"#,
            "offset": #"\[offset:([+-]?\d+)\]"#
        ]
        
        let lrcLines = lrcContent.components(separatedBy: .newlines)
        
        for line in lrcLines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Parse metadata
            if let match = trimmedLine.range(of: metaPatterns["ti"]!, options: .regularExpression) {
                let value = String(trimmedLine[match]).replacingOccurrences(of: "[ti:", with: "").replacingOccurrences(of: "]", with: "")
                title = value
                continue
            }
            
            if let match = trimmedLine.range(of: metaPatterns["ar"]!, options: .regularExpression) {
                let value = String(trimmedLine[match]).replacingOccurrences(of: "[ar:", with: "").replacingOccurrences(of: "]", with: "")
                artist = value
                continue
            }
            
            if let match = trimmedLine.range(of: metaPatterns["offset"]!, options: .regularExpression) {
                let value = String(trimmedLine[match]).replacingOccurrences(of: "[offset:", with: "").replacingOccurrences(of: "]", with: "")
                offset = Int(value) ?? 0
                continue
            }
            
            // Parse timestamp and lyrics content
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let range = NSRange(trimmedLine.startIndex..., in: trimmedLine)
            
            if let match = regex.firstMatch(in: trimmedLine, options: [], range: range) {
                guard let minutesRange = Range(match.range(at: 1), in: trimmedLine),
                      let secondsRange = Range(match.range(at: 2), in: trimmedLine),
                      let millisecondsRange = Range(match.range(at: 3), in: trimmedLine),
                      let contentRange = Range(match.range(at: 4), in: trimmedLine) else { continue }
                
                let minutes = Double(trimmedLine[minutesRange]) ?? 0
                let seconds = Double(trimmedLine[secondsRange]) ?? 0
                var milliseconds = Double(trimmedLine[millisecondsRange]) ?? 0
                
                // Handle two or three digit milliseconds
                if trimmedLine[millisecondsRange].count == 2 {
                    milliseconds *= 10
                }
                
                let time = minutes * 60 + seconds + milliseconds / 1000
                let content = String(trimmedLine[contentRange]).trimmingCharacters(in: .whitespaces)
                
                if !content.isEmpty {
                    lines.append(LyricsLine(time: time, content: content))
                }
            }
        }
        
        // Sort by time
        lines.sort { $0.time < $1.time }
        
        guard !lines.isEmpty else { return nil }
        
        return Lyrics(
            trackID: trackID,
            title: title,
            artist: artist,
            metadata: metadata,
            lines: lines,
            offset: offset
        )
    }
    
    /// Export to LRC format
    func exportToLRC() -> String {
        var result = ""
        
        // Metadata
        if !title.isEmpty {
            result += "[ti:\(title)]\n"
        }
        if !artist.isEmpty {
            result += "[ar:\(artist)]\n"
        }
        if offset != 0 {
            result += "[offset:\(offset)]\n"
        }
        result += "\n"
        
        // Lyrics lines
        for line in lines {
            let totalSeconds = Int(line.time)
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            let milliseconds = Int((line.time - Double(totalSeconds)) * 100)
            
            result += String(format: "[%02d:%02d.%02d]%@\n", minutes, seconds, milliseconds, line.content)
        }
        
        return result
    }
}
