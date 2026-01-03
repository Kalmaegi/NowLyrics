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

/// Unified string similarity calculator using advanced algorithms
enum StringSimilarityCalculator {

    /// Calculate Levenshtein distance between two strings
    /// - Returns: The minimum number of single-character edits required to change one string into the other
    static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let s1Count = s1Array.count
        let s2Count = s2Array.count

        // If either string is empty, distance is the length of the other
        if s1Count == 0 { return s2Count }
        if s2Count == 0 { return s1Count }

        // Create distance matrix
        var matrix = Array(repeating: Array(repeating: 0, count: s2Count + 1), count: s1Count + 1)

        // Initialize first row and column
        for i in 0...s1Count {
            matrix[i][0] = i
        }
        for j in 0...s2Count {
            matrix[0][j] = j
        }

        // Fill in the rest of the matrix
        for i in 1...s1Count {
            for j in 1...s2Count {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }

        return matrix[s1Count][s2Count]
    }

    /// Calculate similarity score between two strings (0.0 to 1.0)
    /// - Parameters:
    ///   - s1: First string
    ///   - s2: Second string
    /// - Returns: Similarity score where 1.0 is identical and 0.0 is completely different
    static func similarity(_ s1: String, _ s2: String) -> Double {
        // Normalize strings: lowercase and trim whitespace
        let normalized1 = s1.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized2 = s2.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle empty strings
        if normalized1.isEmpty && normalized2.isEmpty { return 1.0 }
        if normalized1.isEmpty || normalized2.isEmpty { return 0.0 }

        // Exact match
        if normalized1 == normalized2 { return 1.0 }

        // Check for substring match (bonus points)
        let longer = normalized1.count > normalized2.count ? normalized1 : normalized2
        let shorter = normalized1.count > normalized2.count ? normalized2 : normalized1
        if longer.contains(shorter) {
            return 0.7 + (0.3 * Double(shorter.count) / Double(longer.count))
        }

        // Calculate Levenshtein distance
        let distance = levenshteinDistance(normalized1, normalized2)
        let maxLength = max(normalized1.count, normalized2.count)

        // Convert distance to similarity (0.0 to 1.0)
        let similarity = 1.0 - (Double(distance) / Double(maxLength))

        return max(0.0, similarity)
    }

    /// Calculate relevance score for search result
    /// - Parameters:
    ///   - searchTitle: The title being searched for
    ///   - searchArtist: The artist being searched for
    ///   - resultTitle: The title from search result
    ///   - resultArtist: The artist from search result
    ///   - searchDuration: Optional duration of the track being searched (in seconds)
    ///   - resultDuration: Optional duration of the result track (in seconds)
    /// - Returns: Relevance score (0.0 to 1.0)
    static func calculateRelevance(
        searchTitle: String,
        searchArtist: String,
        resultTitle: String,
        resultArtist: String,
        searchDuration: TimeInterval? = nil,
        resultDuration: TimeInterval? = nil
    ) -> Double {
        let titleSimilarity = similarity(searchTitle, resultTitle)
        let artistSimilarity = similarity(searchArtist, resultArtist)

        // Base score: title 60%, artist 40%
        var score = titleSimilarity * 0.6 + artistSimilarity * 0.4

        // Duration matching bonus (up to 10% boost)
        // Helps distinguish between different versions (original, live, radio edit, etc.)
        if let searchDur = searchDuration, let resultDur = resultDuration, searchDur > 0, resultDur > 0 {
            let durationDiff = abs(searchDur - resultDur)
            if durationDiff < 10 { // Within 10 seconds tolerance
                // Linear scaling: 0s diff = 10% bonus, 10s diff = 0% bonus
                let durationBonus = 0.10 * (1.0 - durationDiff / 10.0)
                score = min(1.0, score + durationBonus)
            }
        }

        return score
    }
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

        AppLogger.info("NetEase 搜索歌词 - URL: \(searchURL.absoluteString)", category: .network)

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
                let resultTitle = song["name"] as? String ?? ""
                let resultArtist = (song["artists"] as? [[String: Any]])?.first?["name"] as? String ?? ""

                // Extract duration (NetEase returns in milliseconds as "dt" or "duration")
                let resultDuration: TimeInterval? = {
                    if let dt = song["dt"] as? Int {
                        return TimeInterval(dt) / 1000.0
                    } else if let dur = song["duration"] as? Int {
                        return TimeInterval(dur) / 1000.0
                    }
                    return nil
                }()

                let score = StringSimilarityCalculator.calculateRelevance(
                    searchTitle: title,
                    searchArtist: artist,
                    resultTitle: resultTitle,
                    resultArtist: resultArtist,
                    searchDuration: duration,
                    resultDuration: resultDuration
                )

                let durationInfo = resultDuration.map { String(format: "%.0fs", $0) } ?? "未知"
                AppLogger.debug("NetEase 匹配结果 - 歌曲: \(resultTitle), 艺术家: \(resultArtist), 时长: \(durationInfo), 评分: \(String(format: "%.3f", score))", category: .lyrics)
                results.append(LyricsSearchResult(lyrics: lyrics, relevanceScore: score))
            }
        }
        
        return results.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    private func fetchLyrics(songId: Int, trackID: String) async throws -> Lyrics? {
        let lyricsURL = URL(string: "\(baseURL)/song/lyric?id=\(songId)&lv=1&tv=1&yrc=1")!

        AppLogger.info("NetEase 获取歌词详情 - URL: \(lyricsURL.absoluteString)", category: .network)

        var request = URLRequest(url: lyricsURL)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        var metadata = LyricsMetadata(source: .netease, sourceID: "\(songId)")

        // Try to parse YRC (word-by-word lyrics) first
        if let yrc = json["yrc"] as? [String: Any],
           let yrcContent = yrc["lyric"] as? String,
           !yrcContent.isEmpty,
           let lyrics = Lyrics.parseYRC(yrcContent: yrcContent, trackID: trackID, metadata: metadata) {
            AppLogger.info("Fetched YRC lyrics with timetags for song \(songId)", category: .lyrics)
            return lyrics
        }

        // Fallback to standard LRC
        if let lrc = json["lrc"] as? [String: Any],
           let lrcContent = lrc["lyric"] as? String {

            // Check if translation exists
            if let tlyric = json["tlyric"] as? [String: Any],
               let _ = tlyric["lyric"] as? String {
                metadata.hasTranslation = true
            }

            return Lyrics.parse(lrcContent: lrcContent, trackID: trackID, metadata: metadata)
        }

        return nil
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

        AppLogger.info("QQ音乐 搜索歌词 - URL: \(searchURL.absoluteString)", category: .network)

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
                let resultTitle = item["songname"] as? String ?? ""
                let resultArtist = (item["singer"] as? [[String: Any]])?.first?["name"] as? String ?? ""

                // Extract duration (QQ Music returns in seconds as "interval")
                let resultDuration: TimeInterval? = {
                    if let interval = item["interval"] as? Int {
                        return TimeInterval(interval)
                    }
                    return nil
                }()

                let score = StringSimilarityCalculator.calculateRelevance(
                    searchTitle: title,
                    searchArtist: artist,
                    resultTitle: resultTitle,
                    resultArtist: resultArtist,
                    searchDuration: duration,
                    resultDuration: resultDuration
                )

                let durationInfo = resultDuration.map { String(format: "%.0fs", $0) } ?? "未知"
                AppLogger.debug("QQ音乐 匹配结果 - 歌曲: \(resultTitle), 艺术家: \(resultArtist), 时长: \(durationInfo), 评分: \(String(format: "%.3f", score))", category: .lyrics)
                results.append(LyricsSearchResult(lyrics: lyrics, relevanceScore: score))
            }
        }
        
        return results.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    private func fetchLyrics(songmid: String, trackID: String) async throws -> Lyrics? {
        let lyricsURL = URL(string: "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=\(songmid)&format=json&nobase64=1")!

        AppLogger.info("QQ音乐 获取歌词详情 - URL: \(lyricsURL.absoluteString)", category: .network)

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
