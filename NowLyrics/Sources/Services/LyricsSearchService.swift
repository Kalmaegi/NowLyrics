//
//  LyricsSearchService.swift
//  NowLyrics
//
//  Created by Hans
//

import Foundation

/// Lyrics search result
struct LyricsSearchResult: Sendable {
    let lyrics: Lyrics
    let relevanceScore: Double
}

/// Lyrics search service protocol
protocol LyricsSearchServiceProtocol: Sendable {
    func search(title: String, artist: String, duration: TimeInterval) async throws -> [LyricsSearchResult]
}

/// NetEase Music lyrics service
actor NetEaseLyricsService: LyricsSearchServiceProtocol {
    
    private let session: URLSession
    private let baseURL = "https://music.163.com/api"
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func search(title: String, artist: String, duration: TimeInterval) async throws -> [LyricsSearchResult] {
        // Search songs
        let searchQuery = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let searchURL = URL(string: "\(baseURL)/search/get?s=\(searchQuery)&type=1&limit=10")!
        
        var request = URLRequest(url: searchURL)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await session.data(for: request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let songs = result["songs"] as? [[String: Any]] else {
            return []
        }
        
        var results: [LyricsSearchResult] = []
        
        for song in songs.prefix(5) {
            guard let songId = song["id"] as? Int else { continue }
            
            if let lyrics = try? await fetchLyrics(songId: songId, trackID: "\(songId)") {
                let score = calculateRelevance(title: title, artist: artist, 
                                               resultTitle: song["name"] as? String ?? "",
                                               resultArtist: (song["artists"] as? [[String: Any]])?.first?["name"] as? String ?? "")
                results.append(LyricsSearchResult(lyrics: lyrics, relevanceScore: score))
            }
        }
        
        return results.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    private func fetchLyrics(songId: Int, trackID: String) async throws -> Lyrics? {
        let lyricsURL = URL(string: "\(baseURL)/song/lyric?id=\(songId)&lv=1&tv=1")!
        
        var request = URLRequest(url: lyricsURL)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await session.data(for: request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lrc = json["lrc"] as? [String: Any],
              let lrcContent = lrc["lyric"] as? String else {
            return nil
        }
        
        var metadata = LyricsMetadata(source: .netease, sourceID: "\(songId)")
        
        // Check if translation exists
        if let tlyric = json["tlyric"] as? [String: Any],
           let _ = tlyric["lyric"] as? String {
            metadata.hasTranslation = true
        }
        
        return Lyrics.parse(lrcContent: lrcContent, trackID: trackID, metadata: metadata)
    }
    
    private func calculateRelevance(title: String, artist: String, resultTitle: String, resultArtist: String) -> Double {
        let titleSimilarity = stringSimilarity(title.lowercased(), resultTitle.lowercased())
        let artistSimilarity = stringSimilarity(artist.lowercased(), resultArtist.lowercased())
        return (titleSimilarity * 0.6 + artistSimilarity * 0.4)
    }
    
    private func stringSimilarity(_ s1: String, _ s2: String) -> Double {
        if s1 == s2 { return 1.0 }
        if s1.isEmpty || s2.isEmpty { return 0.0 }
        
        let longer = s1.count > s2.count ? s1 : s2
        let shorter = s1.count > s2.count ? s2 : s1
        
        if longer.contains(shorter) {
            return Double(shorter.count) / Double(longer.count)
        }
        
        return 0.3
    }
}

/// QQ Music lyrics service
actor QQMusicLyricsService: LyricsSearchServiceProtocol {
    
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func search(title: String, artist: String, duration: TimeInterval) async throws -> [LyricsSearchResult] {
        let searchQuery = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let searchURL = URL(string: "https://c.y.qq.com/soso/fcgi-bin/client_search_cp?w=\(searchQuery)&format=json&n=10")!
        
        var request = URLRequest(url: searchURL)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue("https://y.qq.com", forHTTPHeaderField: "Referer")
        
        let (data, _) = try await session.data(for: request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataDict = json["data"] as? [String: Any],
              let song = dataDict["song"] as? [String: Any],
              let list = song["list"] as? [[String: Any]] else {
            return []
        }
        
        var results: [LyricsSearchResult] = []
        
        for item in list.prefix(5) {
            guard let songmid = item["songmid"] as? String else { continue }
            
            if let lyrics = try? await fetchLyrics(songmid: songmid, trackID: songmid) {
                let score = calculateRelevance(
                    title: title, artist: artist,
                    resultTitle: item["songname"] as? String ?? "",
                    resultArtist: (item["singer"] as? [[String: Any]])?.first?["name"] as? String ?? ""
                )
                results.append(LyricsSearchResult(lyrics: lyrics, relevanceScore: score))
            }
        }
        
        return results.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    private func fetchLyrics(songmid: String, trackID: String) async throws -> Lyrics? {
        let lyricsURL = URL(string: "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=\(songmid)&format=json&nobase64=1")!
        
        var request = URLRequest(url: lyricsURL)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue("https://y.qq.com", forHTTPHeaderField: "Referer")
        
        let (data, _) = try await session.data(for: request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lrcContent = json["lyric"] as? String else {
            return nil
        }
        
        let metadata = LyricsMetadata(source: .qqMusic, sourceID: songmid)
        return Lyrics.parse(lrcContent: lrcContent, trackID: trackID, metadata: metadata)
    }
    
    private func calculateRelevance(title: String, artist: String, resultTitle: String, resultArtist: String) -> Double {
        let titleMatch = title.lowercased() == resultTitle.lowercased() ? 1.0 : 0.5
        let artistMatch = artist.lowercased() == resultArtist.lowercased() ? 1.0 : 0.5
        return (titleMatch * 0.6 + artistMatch * 0.4)
    }
}

/// Combined lyrics search service
actor CombinedLyricsSearchService: LyricsSearchServiceProtocol {
    
    private let services: [any LyricsSearchServiceProtocol]
    
    init(services: [any LyricsSearchServiceProtocol]? = nil) {
        self.services = services ?? [
            NetEaseLyricsService(),
            QQMusicLyricsService()
        ]
    }
    
    func search(title: String, artist: String, duration: TimeInterval) async throws -> [LyricsSearchResult] {
        var allResults: [LyricsSearchResult] = []
        
        await withTaskGroup(of: [LyricsSearchResult].self) { group in
            for service in services {
                group.addTask {
                    do {
                        return try await service.search(title: title, artist: artist, duration: duration)
                    } catch {
                        return []
                    }
                }
            }
            
            for await results in group {
                allResults.append(contentsOf: results)
            }
        }
        
        // Sort by relevance and remove duplicates
        return allResults.sorted { $0.relevanceScore > $1.relevanceScore }
    }
}
