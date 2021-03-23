//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import Foundation

struct Playlist {

    let uri: URL
    let name: String
    let trackCount: UInt

    private (set) var excluded: Bool

    init(uri: URL, name: String, trackCount: UInt, excluded: Bool) {
        self.uri = uri
        self.name = name
        self.trackCount = trackCount
        self.excluded = excluded
    }

    mutating func toggleExcluded() {
        excluded.toggle()
    }
}
