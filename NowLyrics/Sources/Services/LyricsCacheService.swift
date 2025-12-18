//
//  LyricsCacheService.swift
//  NowLyrics
//
//  Created by Hans
//

import Foundation

/// Lyrics cache service protocol
protocol LyricsCacheServiceProtocol: Actor {
    func getCachedLyrics(for trackID: String) async -> Lyrics?
    func cacheLyrics(_ lyrics: Lyrics) async throws
    func getUserSelectedLyrics(for trackID: String) async -> Lyrics?
    func setUserSelectedLyrics(_ lyrics: Lyrics, for trackID: String) async throws
    func getAllCachedLyrics(for trackID: String) async -> [Lyrics]
    func deleteLyrics(_ lyrics: Lyrics) async throws
}

/// Lyrics cache service implementation
actor LyricsCacheService: LyricsCacheServiceProtocol {
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let userPreferencesURL: URL
    private var userPreferences: [String: String] = [:] // trackID -> lyricsID
    
    init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDirectory = appSupport.appendingPathComponent("NowLyrics/Lyrics", isDirectory: true)
        userPreferencesURL = appSupport.appendingPathComponent("NowLyrics/user_preferences.json")
        
        // Ensure directory exists
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Load user preferences
        if let data = try? Data(contentsOf: userPreferencesURL),
           let prefs = try? JSONDecoder().decode([String: String].self, from: data) {
            userPreferences = prefs
        }
    }
    
    private func loadUserPreferences() {
        guard let data = try? Data(contentsOf: userPreferencesURL),
              let prefs = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }
        userPreferences = prefs
    }
    
    private func saveUserPreferences() throws {
        let data = try JSONEncoder().encode(userPreferences)
        try data.write(to: userPreferencesURL)
    }
    
    func getCachedLyrics(for trackID: String) async -> Lyrics? {
        // Prioritize user-selected lyrics
        if let userSelected = await getUserSelectedLyrics(for: trackID) {
            return userSelected
        }
        
        // Otherwise return highest quality cached lyrics
        let allLyrics = await getAllCachedLyrics(for: trackID)
        return allLyrics.max(by: { $0.metadata.quality < $1.metadata.quality })
    }
    
    func cacheLyrics(_ lyrics: Lyrics) async throws {
        let trackDirectory = cacheDirectory.appendingPathComponent(lyrics.trackID, isDirectory: true)
        try fileManager.createDirectory(at: trackDirectory, withIntermediateDirectories: true)
        
        let fileName = "\(lyrics.id.uuidString).lrcx"
        let fileURL = trackDirectory.appendingPathComponent(fileName)
        
        // Save lyrics content
        let lrcContent = lyrics.exportToLRC()
        try lrcContent.write(to: fileURL, atomically: true, encoding: .utf8)
        
        // Save metadata
        let metadataURL = trackDirectory.appendingPathComponent("\(lyrics.id.uuidString).json")
        let metadataData = try JSONEncoder().encode(lyrics.metadata)
        try metadataData.write(to: metadataURL)
    }
    
    func getUserSelectedLyrics(for trackID: String) async -> Lyrics? {
        guard let selectedID = userPreferences[trackID] else { return nil }
        
        let allLyrics = await getAllCachedLyrics(for: trackID)
        return allLyrics.first { $0.id.uuidString == selectedID }
    }
    
    func setUserSelectedLyrics(_ lyrics: Lyrics, for trackID: String) async throws {
        userPreferences[trackID] = lyrics.id.uuidString
        
        // Update lyrics user selection flag
        var updatedLyrics = lyrics
        updatedLyrics.metadata.isUserSelected = true
        try await cacheLyrics(updatedLyrics)
        
        try saveUserPreferences()
    }
    
    func getAllCachedLyrics(for trackID: String) async -> [Lyrics] {
        let trackDirectory = cacheDirectory.appendingPathComponent(trackID, isDirectory: true)
        
        guard let files = try? fileManager.contentsOfDirectory(at: trackDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        
        var lyrics: [Lyrics] = []
        
        let lrcFiles = files.filter { $0.pathExtension == "lrcx" }
        
        for lrcFile in lrcFiles {
            guard let lrcContent = try? String(contentsOf: lrcFile, encoding: .utf8) else { continue }
            
            // Try to load metadata
            let metadataURL = lrcFile.deletingPathExtension().appendingPathExtension("json")
            var metadata = LyricsMetadata()
            
            if let metadataData = try? Data(contentsOf: metadataURL),
               let loadedMetadata = try? JSONDecoder().decode(LyricsMetadata.self, from: metadataData) {
                metadata = loadedMetadata
            }
            
            // Get UUID from filename
            let lyricsID = UUID(uuidString: lrcFile.deletingPathExtension().lastPathComponent) ?? UUID()
            
            if var parsedLyrics = Lyrics.parse(lrcContent: lrcContent, trackID: trackID, metadata: metadata) {
                // Use ID from filename
                parsedLyrics = Lyrics(
                    id: lyricsID,
                    trackID: parsedLyrics.trackID,
                    title: parsedLyrics.title,
                    artist: parsedLyrics.artist,
                    metadata: parsedLyrics.metadata,
                    lines: parsedLyrics.lines,
                    offset: parsedLyrics.offset
                )
                lyrics.append(parsedLyrics)
            }
        }
        
        return lyrics
    }
    
    func deleteLyrics(_ lyrics: Lyrics) async throws {
        let trackDirectory = cacheDirectory.appendingPathComponent(lyrics.trackID, isDirectory: true)
        let lrcURL = trackDirectory.appendingPathComponent("\(lyrics.id.uuidString).lrcx")
        let metadataURL = trackDirectory.appendingPathComponent("\(lyrics.id.uuidString).json")
        
        try? fileManager.removeItem(at: lrcURL)
        try? fileManager.removeItem(at: metadataURL)
        
        // If this is user-selected lyrics, clear preference
        if userPreferences[lyrics.trackID] == lyrics.id.uuidString {
            userPreferences.removeValue(forKey: lyrics.trackID)
            try saveUserPreferences()
        }
    }
}

// MARK: - Lyrics File Import/Export

extension LyricsCacheService {
    
    /// Import lyrics from file
    func importLyrics(from url: URL, for track: Track) async throws -> Lyrics? {
        let content = try String(contentsOf: url, encoding: .utf8)
        
        var metadata = LyricsMetadata(source: .manual)
        metadata.downloadedAt = Date()
        
        guard var lyrics = Lyrics.parse(lrcContent: content, trackID: track.id, metadata: metadata) else {
            return nil
        }
        
        lyrics.title = track.title
        lyrics.artist = track.artist
        
        try await cacheLyrics(lyrics)
        return lyrics
    }
    
    /// Export lyrics to file
    func exportLyrics(_ lyrics: Lyrics, to url: URL) async throws {
        let content = lyrics.exportToLRC()
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
