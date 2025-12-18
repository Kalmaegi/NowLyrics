//
//  Track.swift
//  NowLyrics
//
//  Created by Hans
//

import Foundation

/// Represents the currently playing music track
struct Track: Equatable, Hashable, Sendable {
    /// Unique track identifier
    let id: String
    /// Song title
    let title: String
    /// Artist name
    let artist: String
    /// Album name
    let album: String?
    /// Song duration (seconds)
    let duration: TimeInterval
    /// Album artwork URL
    let artworkURL: URL?
    
    /// Generate query keywords for lyrics search
    var searchQuery: String {
        "\(title) \(artist)"
    }
    
    /// Generate safe filename for file saving
    var safeFileName: String {
        let safeName = "\(title) - \(artist)"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        return safeName
    }
}

extension Track {
    /// Create an empty placeholder track
    static let empty = Track(
        id: "",
        title: "",
        artist: "",
        album: nil,
        duration: 0,
        artworkURL: nil
    )
    
    /// Check if this is an empty track
    var isEmpty: Bool {
        id.isEmpty && title.isEmpty
    }
}
