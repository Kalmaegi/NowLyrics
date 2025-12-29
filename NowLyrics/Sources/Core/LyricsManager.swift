//
//  LyricsManager.swift
//  NowLyrics
//
//  Created by Hans
//

import Foundation

/// Lyrics manager - coordinates music playback, lyrics search and caching
@MainActor
final class LyricsManager {
    
    // MARK: - State Properties
    private(set) var currentTrack: Track?
    private(set) var currentLyrics: Lyrics?
    private(set) var currentLineIndex: Int?
    private(set) var playbackState: PlaybackState = .stopped
    private(set) var isSearchingLyrics = false
    private(set) var availableLyrics: [Lyrics] = []
    
    // MARK: - Services
    private let musicService: AppleMusicService
    private let searchService: CombinedLyricsSearchService
    private let cacheService: LyricsCacheService
    
    // MARK: - Tasks
    private var lineUpdateTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    
    // MARK: - State Change Streams
    private let trackContinuation: AsyncStream<Track?>.Continuation
    private let lyricsContinuation: AsyncStream<Lyrics?>.Continuation
    private let lineIndexContinuation: AsyncStream<Int?>.Continuation
    private let playbackStateContinuation: AsyncStream<PlaybackState>.Continuation
    private let searchingContinuation: AsyncStream<Bool>.Continuation
    private let availableLyricsContinuation: AsyncStream<[Lyrics]>.Continuation
    
    // MARK: - Public Streams
    let trackStream: AsyncStream<Track?>
    let lyricsStream: AsyncStream<Lyrics?>
    let lineIndexStream: AsyncStream<Int?>
    let playbackStateStream: AsyncStream<PlaybackState>
    let searchingStream: AsyncStream<Bool>
    let availableLyricsStream: AsyncStream<[Lyrics]>
    
    init(
        musicService: AppleMusicService = AppleMusicService(),
        searchService: CombinedLyricsSearchService = CombinedLyricsSearchService(),
        cacheService: LyricsCacheService = LyricsCacheService()
    ) {
        self.musicService = musicService
        self.searchService = searchService
        self.cacheService = cacheService
        
        // Initialize AsyncStreams
        (trackStream, trackContinuation) = AsyncStream.makeStream(of: Track?.self)
        (lyricsStream, lyricsContinuation) = AsyncStream.makeStream(of: Lyrics?.self)
        (lineIndexStream, lineIndexContinuation) = AsyncStream.makeStream(of: Int?.self)
        (playbackStateStream, playbackStateContinuation) = AsyncStream.makeStream(of: PlaybackState.self)
        (searchingStream, searchingContinuation) = AsyncStream.makeStream(of: Bool.self)
        (availableLyricsStream, availableLyricsContinuation) = AsyncStream.makeStream(of: [Lyrics].self)
        
        // Send initial values
        trackContinuation.yield(currentTrack)
        lyricsContinuation.yield(currentLyrics)
        lineIndexContinuation.yield(currentLineIndex)
        playbackStateContinuation.yield(playbackState)
        searchingContinuation.yield(isSearchingLyrics)
        availableLyricsContinuation.yield(availableLyrics)
    }
    
    deinit {
        trackContinuation.finish()
        lyricsContinuation.finish()
        lineIndexContinuation.finish()
        playbackStateContinuation.finish()
        searchingContinuation.finish()
        availableLyricsContinuation.finish()
    }
    
    func start() async {
        await setupCallbacks()
        await musicService.startObserving()
    }
    
    func stop() async {
        await musicService.stopObserving()
        lineUpdateTask?.cancel()
        searchTask?.cancel()
    }
    
    func selectLyrics(_ lyrics: Lyrics) async {
        currentLyrics = lyrics
        lyricsContinuation.yield(lyrics)
        try? await cacheService.setUserSelectedLyrics(lyrics, for: lyrics.trackID)
        scheduleLineUpdate()
    }
    
    func searchMoreLyrics() async {
        guard let track = currentTrack else { return }
        setSearchingState(true)
        defer { setSearchingState(false) }
        
        do {
            let results = try await searchService.search(title: track.title, artist: track.artist, duration: track.duration)
            for result in results {
                var lyrics = result.lyrics
                lyrics.metadata.quality = Int(result.relevanceScore * 100)
                try await cacheService.cacheLyrics(lyrics)
            }
            let newAvailableLyrics = await cacheService.getAllCachedLyrics(for: track.id)
            setAvailableLyrics(newAvailableLyrics)
        } catch {
            print("Failed to search lyrics: \(error)")
        }
    }
    
    func adjustOffset(by milliseconds: Int) {
        guard var lyrics = currentLyrics else { return }
        lyrics.offset += milliseconds
        currentLyrics = lyrics
        lyricsContinuation.yield(lyrics)
        Task { try? await cacheService.cacheLyrics(lyrics) }
    }
    
    // MARK: - Private State Updates
    
    private func setCurrentTrack(_ track: Track?) {
        currentTrack = track
        trackContinuation.yield(track)
    }
    
    private func setCurrentLyrics(_ lyrics: Lyrics?) {
        currentLyrics = lyrics
        lyricsContinuation.yield(lyrics)
    }
    
    private func setCurrentLineIndex(_ index: Int?) {
        currentLineIndex = index
        lineIndexContinuation.yield(index)
    }
    
    private func setPlaybackState(_ state: PlaybackState) {
        playbackState = state
        playbackStateContinuation.yield(state)
    }
    
    private func setSearchingState(_ isSearching: Bool) {
        isSearchingLyrics = isSearching
        searchingContinuation.yield(isSearching)
    }
    
    private func setAvailableLyrics(_ lyrics: [Lyrics]) {
        availableLyrics = lyrics
        availableLyricsContinuation.yield(lyrics)
    }
    
    private func setupCallbacks() async {
        await musicService.setOnTrackChanged { [weak self] track in
            Task { @MainActor in await self?.handleTrackChanged(track) }
        }
        await musicService.setOnPlaybackStateChanged { [weak self] state in
            Task { @MainActor in self?.handlePlaybackStateChanged(state) }
        }
    }
    
    private func handleTrackChanged(_ track: Track?) async {
        AppLogger.info("Track changed: \(track?.title ?? "nil") - \(track?.artist ?? "nil")", category: .lyrics)
        
        if let currentLyrics = currentLyrics {
            try? await cacheService.cacheLyrics(currentLyrics)
        }
        
        setCurrentTrack(track)
        setCurrentLyrics(nil)
        setCurrentLineIndex(nil)
        setAvailableLyrics([])
        
        guard let track = track, !track.isEmpty else {
            AppLogger.debug("Track is nil or empty, clearing lyrics", category: .lyrics)
            return
        }
        
        AppLogger.debug("Looking for cached lyrics for track: \(track.id)", category: .lyrics)
        
        if let cachedLyrics = await cacheService.getCachedLyrics(for: track.id) {
            AppLogger.info("Found cached lyrics with \(cachedLyrics.lines.count) lines", category: .lyrics)
            setCurrentLyrics(cachedLyrics)
            let allLyrics = await cacheService.getAllCachedLyrics(for: track.id)
            setAvailableLyrics(allLyrics)
            scheduleLineUpdate()
            return
        }
        
        AppLogger.debug("No cached lyrics found, starting search", category: .lyrics)
        await searchLyricsForCurrentTrack()
    }
    
    private func handlePlaybackStateChanged(_ state: PlaybackState) {
        setPlaybackState(state)
        if state.status.isPlaying {
            scheduleLineUpdate()
        } else {
            lineUpdateTask?.cancel()
        }
    }
    
    private func searchLyricsForCurrentTrack() async {
        searchTask?.cancel()
        guard let track = currentTrack else { return }
        setSearchingState(true)
        
        searchTask = Task {
            defer { Task { @MainActor in self.setSearchingState(false) } }
            
            do {
                let results = try await searchService.search(title: track.title, artist: track.artist, duration: track.duration)
                guard !Task.isCancelled, !results.isEmpty else { return }
                
                for result in results {
                    var lyrics = result.lyrics
                    lyrics.metadata.quality = Int(result.relevanceScore * 100)
                    try await cacheService.cacheLyrics(lyrics)
                }
                
                if let best = results.first {
                    await MainActor.run {
                        self.setCurrentLyrics(best.lyrics)
                        self.scheduleLineUpdate()
                    }
                }
                
                let allLyrics = await cacheService.getAllCachedLyrics(for: track.id)
                await MainActor.run { self.setAvailableLyrics(allLyrics) }
            } catch {
                print("Failed to search lyrics: \(error)")
            }
        }
    }
    
    private func scheduleLineUpdate() {
        lineUpdateTask?.cancel()
        guard let lyrics = currentLyrics, playbackState.status.isPlaying else { return }
        
        lineUpdateTask = Task {
            while !Task.isCancelled {
                let currentTime = playbackState.currentPosition()
                let newIndex = lyrics.lineIndex(at: currentTime)
                if newIndex != currentLineIndex { setCurrentLineIndex(newIndex) }
                
                let sleepDuration: UInt64
                if let index = newIndex, index + 1 < lyrics.lines.count {
                    let nextTime = lyrics.lines[index + 1].time - lyrics.offsetInSeconds
                    sleepDuration = UInt64(max(0.05, nextTime - currentTime) * 1_000_000_000)
                } else {
                    sleepDuration = 100_000_000
                }
                try? await Task.sleep(nanoseconds: sleepDuration)
            }
        }
    }
}

extension AppleMusicService {
    func setOnTrackChanged(_ callback: @escaping @Sendable (Track?) -> Void) async {
        onTrackChanged = callback
    }
    func setOnPlaybackStateChanged(_ callback: @escaping @Sendable (PlaybackState) -> Void) async {
        onPlaybackStateChanged = callback
    }
}
