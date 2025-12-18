//
//  Logger.swift
//  NowLyrics
//
//  Created by Hans
//

import Foundation
import os

/// Log level enumeration
public enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case notice = "NOTICE"
    case warning = "WARNING"
    case error = "ERROR"
    case fault = "FAULT"
    
    /// Corresponding os.log type
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .notice: return .default
        case .warning: return .default
        case .error: return .error
        case .fault: return .fault
        }
    }
}

/// Log category enumeration
public enum LogCategory: String, CaseIterable {
    case app = "App"                    // Application lifecycle
    case ui = "UI"                      // User interface related
    case lyrics = "Lyrics"              // Lyrics processing
    case music = "Music"                // Music playback
    case network = "Network"            // Network requests
    case cache = "Cache"                // Cache operations
    case localization = "Localization"  // Internationalization
    case performance = "Performance"     // Performance monitoring
    
    /// Corresponding os.Logger
    func createOSLogger() -> os.Logger {
        return os.Logger(subsystem: LoggerManager.subsystem, category: self.rawValue)
    }
}

/// Unified log manager
///
/// Usage example:
/// ```swift
/// LoggerManager.shared.info("Application started", category: .app)
/// LoggerManager.shared.error("Network request failed: \(error)", category: .network)
/// ```
public final class LoggerManager {
    
    // MARK: - Singleton
    
    public static let shared = LoggerManager()
    
    // MARK: - Constants
    
    static let subsystem = "com.hans.nowlyrics"
    
    // MARK: - Properties
    
    /// Whether debug logging is enabled (automatically disabled in Release builds)
    public var isDebugEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    
    /// Date formatter for logs
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    /// Logger cache for each category
    private var loggers: [LogCategory: os.Logger] = [:]
    
    // MARK: - Initialization
    
    private init() {
        // Pre-create loggers for all categories
        LogCategory.allCases.forEach { category in
            loggers[category] = category.createOSLogger()
        }
    }
    
    // MARK: - Public Methods
    
    /// Get logger for specified category
    public func logger(for category: LogCategory) -> os.Logger {
        return loggers[category] ?? category.createOSLogger()
    }
    
    /// Debug level log
    /// - Parameters:
    ///   - message: Log message
    ///   - category: Log category
    ///   - file: File name
    ///   - function: Function name
    ///   - line: Line number
    public func debug(
        _ message: @autoclosure () -> String,
        category: LogCategory = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isDebugEnabled else { return }
        log(level: .debug, message: message(), category: category, file: file, function: function, line: line)
    }
    
    /// Info level log
    public func info(
        _ message: @autoclosure () -> String,
        category: LogCategory = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, message: message(), category: category, file: file, function: function, line: line)
    }
    
    /// Notice level log (important information)
    public func notice(
        _ message: @autoclosure () -> String,
        category: LogCategory = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .notice, message: message(), category: category, file: file, function: function, line: line)
    }
    
    /// Warning level log
    public func warning(
        _ message: @autoclosure () -> String,
        category: LogCategory = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .warning, message: message(), category: category, file: file, function: function, line: line)
    }
    
    /// Error level log
    public func error(
        _ message: @autoclosure () -> String,
        category: LogCategory = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .error, message: message(), category: category, file: file, function: function, line: line)
    }
    
    /// Fault level log (critical errors)
    public func fault(
        _ message: @autoclosure () -> String,
        category: LogCategory = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .fault, message: message(), category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Private Methods
    
    /// Core logging method
    private func log(
        level: LogLevel,
        message: String,
        category: LogCategory,
        file: String,
        function: String,
        line: Int
    ) {
        let logger = logger(for: category)
        let fileName = (file as NSString).lastPathComponent
        
        #if DEBUG
        // Debug version: add file and line number information
        let formattedMessage = "[\(fileName):\(line)] \(function) - \(message)"
        #else
        // Release version: keep only message content
        let formattedMessage = message
        #endif
        
        // Output using os.log
        switch level {
        case .debug:
            logger.debug("\(formattedMessage)")
        case .info:
            logger.info("\(formattedMessage)")
        case .notice:
            logger.notice("\(formattedMessage)")
        case .warning:
            logger.warning("\(formattedMessage)")
        case .error:
            logger.error("\(formattedMessage)")
        case .fault:
            logger.fault("\(formattedMessage)")
        }
    }
}

// MARK: - Convenient Access

/// Global logging functions providing more concise access
///
/// Usage example:
/// ```swift
/// AppLogger.info("Application started")
/// AppLogger.error("Network error: \(error)")
/// ```
public enum AppLogger {
    
    /// Debug log
    public static func debug(
        _ message: @autoclosure () -> String,
        category: LogCategory = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        LoggerManager.shared.debug(message(), category: category, file: file, function: function, line: line)
    }
    
    /// Info log
    public static func info(
        _ message: @autoclosure () -> String,
        category: LogCategory = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        LoggerManager.shared.info(message(), category: category, file: file, function: function, line: line)
    }
    
    /// Notice log
    public static func notice(
        _ message: @autoclosure () -> String,
        category: LogCategory = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        LoggerManager.shared.notice(message(), category: category, file: file, function: function, line: line)
    }
    
    /// Warning log
    public static func warning(
        _ message: @autoclosure () -> String,
        category: LogCategory = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        LoggerManager.shared.warning(message(), category: category, file: file, function: function, line: line)
    }
    
    /// Error log
    public static func error(
        _ message: @autoclosure () -> String,
        category: LogCategory = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        LoggerManager.shared.error(message(), category: category, file: file, function: function, line: line)
    }
    
    /// Fault log
    public static func fault(
        _ message: @autoclosure () -> String,
        category: LogCategory = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        LoggerManager.shared.fault(message(), category: category, file: file, function: function, line: line)
    }
}

// MARK: - Extensions: Convenience methods for specific categories

extension LoggerManager {
    
    // MARK: - Application related logs
    
    public func appInfo(_ message: String) {
        info(message, category: .app)
    }
    
    public func appError(_ message: String) {
        error(message, category: .app)
    }
    
    // MARK: - Lyrics related logs
    
    public func lyricsInfo(_ message: String) {
        info(message, category: .lyrics)
    }
    
    public func lyricsError(_ message: String) {
        error(message, category: .lyrics)
    }
    
    // MARK: - Network related logs
    
    public func networkInfo(_ message: String) {
        info(message, category: .network)
    }
    
    public func networkError(_ message: String) {
        error(message, category: .network)
    }
    
    // MARK: - UI related logs
    
    public func uiInfo(_ message: String) {
        info(message, category: .ui)
    }
    
    public func uiError(_ message: String) {
        error(message, category: .ui)
    }
}
