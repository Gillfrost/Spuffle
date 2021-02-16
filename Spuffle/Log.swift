//  Copyright (c) 2020 André Gillfrost
//  Licensed under the MIT license

import Foundation
import Combine

struct Log: Hashable {

    enum Level { case info, error }

    #if DEBUG
    static var logs: AnyPublisher<[Log], Never> {
        logsSubject.eraseToAnyPublisher()
    }

    private static let logsSubject = CurrentValueSubject<[Log], Never>([])

    let date: Date
    let level: Level
    let message: String
    let location: String?

    #else
    private init() {}
    #endif
}

extension Log {

    static var errorAction: ((String) -> Void)?

    static func info(_ message: String) {
        log(.info, message)
    }

    static func error(_ error: Error,
                      file: StaticString = #file,
                      line: UInt = #line) {

        self.error(error.localizedDescription,
                   file: file,
                   line: line)
    }

    static func error(_ message: String,
                      file: StaticString = #file,
                      line: UInt = #line) {

        let location = self.location(file: file, line: line)
        log(.error, message, location: location)
    }
}

extension Log {

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium

        return formatter
    }()

    private static func location(file: StaticString, line: UInt) -> String {
        let file = file
            .description
            .components(separatedBy: "/")
            .last ?? ""

        return "(\(file):\(line))"
    }

    private static func log(_ level: Level,
                            _ message: String,
                            location: String? = nil) {

        #if DEBUG
        let date = Date()
        let log = Log(date: date,
                      level: level,
                      message: message,
                      location: location)

        logsSubject.value += [log]

        let formattedLog = format(date, level, message, location: location)
        print(formattedLog)
        #endif

        if level == .error {
            errorAction?(message)
        }
    }

    private static func format(_ date: Date, _ level: Level, _ message: String, location: String?) -> String {

        let date = dateFormatter.string(from: date)

        let logLevel = "\(level)"
            .uppercased()

        return [date, logLevel, "\t\(message)", location]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
