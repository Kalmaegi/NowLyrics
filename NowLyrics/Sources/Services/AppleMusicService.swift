//
//  AppleMusicService.swift
//  NowLyrics
//
//  Created by Hans
//

import AppKit
import Foundation

/// Apple Music service protocol
protocol MusicPlayerServiceProtocol: Actor {
    /// Currently playing track
    var currentTrack: Track? { get async }
    /// Current playback state
    var playbackState: PlaybackState { get async }
    /// Start observing playback state changes
    func startObserving() async
    /// Stop observing
    func stopObserving() async
    /// Track change callback
    var onTrackChanged: (@Sendable (Track?) -> Void)? { get set }
    /// Playback state change callback
    var onPlaybackStateChanged: (@Sendable (PlaybackState) -> Void)? { get set }
}

/// Apple Music service implementation, gets playback information through AppleScript
actor AppleMusicService: MusicPlayerServiceProtocol {
    
    private var _currentTrack: Track?
    private var _playbackState: PlaybackState = .stopped
    private var observationTask: Task<Void, Never>?
    private var isObserving = false
    
    var onTrackChanged: (@Sendable (Track?) -> Void)?
    var onPlaybackStateChanged: (@Sendable (PlaybackState) -> Void)?
    
    var currentTrack: Track? { _currentTrack }
    var playbackState: PlaybackState { _playbackState }
    
    private let getTrackScript = """
    tell application "Music"
        if it is running then
            if player state is not stopped then
                set trackId to persistent ID of current track
                set trackTitle to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                set trackDuration to duration of current track
                return trackId & "|||" & trackTitle & "|||" & trackArtist & "|||" & trackAlbum & "|||" & trackDuration
            end if
        end if
        return ""
    end tell
    """
    
    private let getPlaybackStateScript = """
    tell application "Music"
        if it is running then
            set playerPosition to player position
            if player state is playing then
                return "playing|||" & playerPosition
            else if player state is paused then
                return "paused|||" & playerPosition
            else
                return "stopped|||0"
            end if
        end if
        return "stopped|||0"
    end tell
    """
    
    func startObserving() async {
        guard !isObserving else { return }
        isObserving = true
        
        observationTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.updatePlaybackInfo()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
    
    func stopObserving() async {
        isObserving = false
        observationTask?.cancel()
        observationTask = nil
    }
    
    private func updatePlaybackInfo() async {
        let track = await fetchCurrentTrack()
        let state = await fetchPlaybackState()
        updateState(track: track, playbackState: state)
    }
    
    private func updateState(track: Track?, playbackState: PlaybackState) {
        let trackChanged = _currentTrack != track
        let stateChanged = _playbackState != playbackState
        
        _currentTrack = track
        _playbackState = playbackState
        
        if trackChanged { onTrackChanged?(track) }
        if stateChanged { onPlaybackStateChanged?(playbackState) }
    }
    
    private func fetchCurrentTrack() async -> Track? {
        guard let script = NSAppleScript(source: getTrackScript) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil else { return nil }
        
        let resultString = result.stringValue ?? ""
        guard !resultString.isEmpty else { return nil }
        
        let components = resultString.components(separatedBy: "|||")
        guard components.count >= 5 else { return nil }
        
        return Track(
            id: components[0],
            title: components[1],
            artist: components[2],
            album: components[3].isEmpty ? nil : components[3],
            duration: TimeInterval(components[4]) ?? 0,
            artworkURL: nil
        )
    }
    
    private func fetchPlaybackState() async -> PlaybackState {
        guard let script = NSAppleScript(source: getPlaybackStateScript) else { return .stopped }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil else { return .stopped }
        
        let resultString = result.stringValue ?? "stopped|||0"
        let components = resultString.components(separatedBy: "|||")
        guard components.count >= 2 else { return .stopped }
        
        let status: PlaybackStatus = switch components[0] {
        case "playing": .playing
        case "paused": .paused
        default: .stopped
        }
        
        return PlaybackState(status: status, position: TimeInterval(components[1]) ?? 0, timestamp: Date())
    }
}
