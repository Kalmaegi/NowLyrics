//
//  PlaybackState.swift
//  NowLyrics
//
//  Created by Hans
//

import Foundation

/// Playback status enumeration
enum PlaybackStatus: Equatable, Sendable {
    case playing
    case paused
    case stopped
    case unknown
    
    var isPlaying: Bool {
        self == .playing
    }
}

/// Player state
struct PlaybackState: Equatable, Sendable {
    /// Current playback status
    let status: PlaybackStatus
    /// Current playback position (seconds)
    let position: TimeInterval
    /// Status update time
    let timestamp: Date
    
    init(status: PlaybackStatus = .stopped, position: TimeInterval = 0, timestamp: Date = Date()) {
        self.status = status
        self.position = position
        self.timestamp = timestamp
    }
    
    /// Calculate actual playback position considering elapsed time
    func currentPosition() -> TimeInterval {
        guard status.isPlaying else { return position }
        let elapsed = Date().timeIntervalSince(timestamp)
        return position + elapsed
    }
    
    static let stopped = PlaybackState(status: .stopped, position: 0)
}
