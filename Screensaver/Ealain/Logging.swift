//
//  Logging.swift
//  Ealain
//
//  Created by Brad Root on 4/11/24.
//

import Foundation

open class Log {
    public enum Level: Int {
        case verbose
        case debug
        case info
        case warn
        case error
        case off

        var name: String {
            switch self {
            case .verbose: "Verbose"
            case .debug: "Debug"
            case .info: "Info"
            case .warn: "Warn"
            case .error: "Error"
            case .off: "Disabled"
            }
        }

        var emoji: String {
            switch self {
            case .verbose: "📖"
            case .debug: "🐝"
            case .info: "✏️"
            case .warn: "⚠️"
            case .error: "⁉️"
            case .off: ""
            }
        }
    }

    public static var logLevel: Level = .off

    public static var useEmoji: Bool = true

    public static var handler: ((Level, String) -> Void)?

    private static let dateformatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "Y-MM-dd H:m:ss.SSSS"
        return dateFormatter
    }()

    private static func log(
        _ object: @autoclosure () -> some Any, level: Log.Level,
        _ fileName: String, _: String, _ line: Int
    ) {
        if logLevel.rawValue <= level.rawValue {
            let date = Log.dateformatter.string(from: Date())
            let components: [String] = fileName.components(separatedBy: "/")
            let objectName = components.last ?? "Unknown Object"
            let levelString =
                Log.useEmoji ? level.emoji : "|" + level.name.uppercased() + "|"
            let logString =
                "\(levelString) [\(date)]: \(object()) [\(objectName): \(line)]"
            print(logString)
            handler?(level, logString)
        }
    }

    public static func error(
        _ object: @autoclosure () -> some Any,
        _ fileName: String = #file,
        _ functionName: String = #function,
        _ line: Int = #line
    ) {
        log(object(), level: .error, fileName, functionName, line)
    }

    public static func warn(
        _ object: @autoclosure () -> some Any,
        _ fileName: String = #file,
        _ functionName: String = #function,
        _ line: Int = #line
    ) {
        log(object(), level: .warn, fileName, functionName, line)
    }

    public static func info(
        _ object: @autoclosure () -> some Any,
        _ fileName: String = #file,
        _ functionName: String = #function,
        _ line: Int = #line
    ) {
        log(object(), level: .info, fileName, functionName, line)
    }

    public static func debug(
        _ object: @autoclosure () -> some Any,
        _ fileName: String = #file,
        _ functionName: String = #function,
        _ line: Int = #line
    ) {
        log(object(), level: .debug, fileName, functionName, line)
    }

    public static func verbose(
        _ object: @autoclosure () -> some Any,
        _ fileName: String = #file,
        _ functionName: String = #function,
        _ line: Int = #line
    ) {
        log(object(), level: .verbose, fileName, functionName, line)
    }
}
