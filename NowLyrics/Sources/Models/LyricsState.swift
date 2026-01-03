//
//  LyricsState.swift
//  NowLyrics
//
//  Created by Hans
//

import Foundation

/// Lyrics availability state
enum LyricsState: Equatable, Sendable {
    case idle                          // Initial state, no track playing
    case searching                     // Searching for lyrics
    case found(Lyrics)                 // Lyrics found and loaded
    case notFound(reason: NotFoundReason)  // Lyrics not available
    case error(ErrorType)              // Error occurred

    /// Reason for lyrics not being found
    enum NotFoundReason: Equatable, Sendable {
        case searchFailed              // Searched but no results
        case userMarked                // User marked as no lyrics
        case incompleteTrackInfo       // Track info is incomplete
    }

    /// Error type
    enum ErrorType: Equatable, Sendable {
        case networkError              // Network request failed
        case parseError                // Failed to parse lyrics
    }

    // MARK: - Display Properties

    /// User-facing display message
    var displayMessage: String {
        switch self {
        case .idle:
            return ""
        case .searching:
            return "搜索歌词中..."
        case .found:
            return ""
        case .notFound(let reason):
            switch reason {
            case .searchFailed:
                return "未找到歌词"
            case .userMarked:
                return "已标记为无歌词"
            case .incompleteTrackInfo:
                return "曲目信息不完整"
            }
        case .error(let errorType):
            switch errorType {
            case .networkError:
                return "网络错误，无法获取歌词"
            case .parseError:
                return "歌词解析失败"
            }
        }
    }

    /// Icon or emoji for display
    var displayIcon: String {
        switch self {
        case .idle:
            return ""
        case .searching:
            return "🔍"
        case .found:
            return ""
        case .notFound(let reason):
            switch reason {
            case .searchFailed:
                return "❌"
            case .userMarked:
                return "🚫"
            case .incompleteTrackInfo:
                return "ℹ️"
            }
        case .error:
            return "⚠️"
        }
    }

    /// Whether user can retry searching
    var canRetry: Bool {
        switch self {
        case .notFound(.searchFailed), .error(.networkError):
            return true
        default:
            return false
        }
    }

    /// Whether user can mark as no lyrics
    var canMarkAsNoLyrics: Bool {
        switch self {
        case .notFound(.searchFailed):
            return true
        default:
            return false
        }
    }

    /// Whether this state has actual lyrics to display
    var hasLyrics: Bool {
        if case .found = self {
            return true
        }
        return false
    }

    // MARK: - Equatable

    static func == (lhs: LyricsState, rhs: LyricsState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.searching, .searching):
            return true
        case (.found(let l), .found(let r)):
            return l.trackID == r.trackID
        case (.notFound(let l), .notFound(let r)):
            return l == r
        case (.error(let l), .error(let r)):
            return l == r
        default:
            return false
        }
    }
}

/// Track type detection for special handling
enum TrackType: Sendable {
    case normal                        // Regular song
    case instrumental                  // Instrumental/pure music
    case podcast                       // Podcast or audiobook
    case live                          // Live performance
    case remix                         // DJ mix or remix

    /// Detect track type from track information
    static func detect(from track: Track) -> TrackType {
        let title = track.title.lowercased()
        let artist = track.artist.lowercased()

        // Check for instrumental
        let instrumentalKeywords = [
            "instrumental", "intro", "outro", "interlude", "prelude",
            "纯音乐", "伴奏", "配乐", "背景音乐"
        ]
        if instrumentalKeywords.contains(where: { title.contains($0) }) {
            return .instrumental
        }

        // Check for podcast/audiobook (long duration)
        if track.duration > 1800 { // > 30 minutes
            return .podcast
        }

        let podcastKeywords = ["podcast", "episode", "有声书", "广播", "ep.", "第", "集"]
        if podcastKeywords.contains(where: { title.contains($0) || artist.contains($0) }) {
            return .podcast
        }

        // Check for live performance
        let liveKeywords = ["live", "现场", "演唱会", "concert"]
        if liveKeywords.contains(where: { title.contains($0) }) {
            return .live
        }

        // Check for remix/mashup
        let remixKeywords = ["remix", "mix", "mashup", "edit", "混音"]
        if remixKeywords.contains(where: { title.contains($0) }) {
            return .remix
        }

        return .normal
    }

    /// Display hint for this track type
    var displayHint: String? {
        switch self {
        case .normal:
            return nil
        case .instrumental:
            return "🎼 纯音乐"
        case .podcast:
            return "📻 播客"
        case .live:
            return "🎤 现场版"
        case .remix:
            return "🎧 混音版"
        }
    }
}
