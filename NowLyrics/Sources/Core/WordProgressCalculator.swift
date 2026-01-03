//
//  WordProgressCalculator.swift
//  NowLyrics
//
//  Created by Hans
//

import Foundation

/// Word-by-word progress calculator for karaoke effect
struct WordProgressCalculator {

    /// Calculate karaoke progress for the current line (0.0 - 1.0)
    /// - Parameters:
    ///   - line: Current lyrics line
    ///   - currentTime: Current playback time (seconds)
    ///   - nextLineTime: Start time of next line (seconds), used for uniform simulation
    /// - Returns: Progress value 0.0-1.0
    static func calculateProgress(
        for line: LyricsLine,
        currentTime: TimeInterval,
        nextLineTime: TimeInterval?
    ) -> Double {
        // Calculate time offset relative to line start
        let relativeTime = currentTime - line.time

        // If before this line, return 0
        guard relativeTime >= 0 else {
            return 0.0
        }

        // If has word-by-word timetags, use precise calculation
        if let timetags = line.timetags, !timetags.isEmpty {
            return calculateProgressWithTimetags(timetags: timetags, relativeTime: relativeTime)
        }

        // Otherwise use uniform simulation
        return calculateProgressUniform(
            relativeTime: relativeTime,
            lineTime: line.time,
            nextLineTime: nextLineTime
        )
    }

    /// Precise progress calculation based on word-by-word timetags
    private static func calculateProgressWithTimetags(
        timetags: [WordTimetag],
        relativeTime: TimeInterval
    ) -> Double {
        // Find how many characters should be highlighted
        var highlightedChars = 0

        for (index, timetag) in timetags.enumerated() {
            if relativeTime >= timetag.timeOffset {
                highlightedChars = index + 1
            } else {
                break
            }
        }

        // If past the last character, return 1.0
        if highlightedChars >= timetags.count {
            return 1.0
        }

        // Calculate progress (based on character count)
        let totalChars = timetags.count
        let baseProgress = Double(highlightedChars) / Double(totalChars)

        // Optional: Add intra-character interpolation for smoother progress
        if highlightedChars < timetags.count {
            let currentTag = timetags[highlightedChars]
            let nextTag = timetags.count > highlightedChars + 1 ? timetags[highlightedChars + 1] : nil

            if let nextTag = nextTag {
                let charDuration = nextTag.timeOffset - currentTag.timeOffset
                guard charDuration > 0 else { return baseProgress }

                let charProgress = (relativeTime - currentTag.timeOffset) / charDuration
                let interpolation = min(1.0, max(0.0, charProgress)) / Double(totalChars)
                return baseProgress + interpolation
            }
        }

        return baseProgress
    }

    /// Uniform simulation progress calculation (when no timetags available)
    private static func calculateProgressUniform(
        relativeTime: TimeInterval,
        lineTime: TimeInterval,
        nextLineTime: TimeInterval?
    ) -> Double {
        guard let nextLineTime = nextLineTime else {
            // If last line, assume 3 seconds duration
            let assumedDuration: TimeInterval = 3.0
            let progress = relativeTime / assumedDuration
            return min(1.0, max(0.0, progress))
        }

        let lineDuration = nextLineTime - lineTime
        guard lineDuration > 0 else { return 1.0 }

        let progress = relativeTime / lineDuration
        return min(1.0, max(0.0, progress))
    }
}
