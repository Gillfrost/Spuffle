//  Copyright (c) 2020 André Gillfrost
//  Licensed under the MIT license

import Foundation

enum Log {

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    static func error(_ message: String,
                      file: StaticString = #file,
                      line: UInt = #line) {

        let date = dateFormatter.string(from: Date())

        let file = file
            .description
            .components(separatedBy: "/")
            .last
            ?? ""

        print("\(date)  \(message)  (\(file):\(line))")
    }
}
