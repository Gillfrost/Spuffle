//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import XCTest
@testable import Spuffle

final class RandomPlaylistPickerTests: XCTestCase {

    func testNoPlaylistIsPickedFromEmptyArray() {
        XCTAssertNil(Picker.pickRandomPlaylist(from: []))
    }

    func testNoPlaylistIsPickedIfEmpty() {
        let emptyPlaylist = Playlist.mock(name: "Empty",
                                          trackCount: 0)

        XCTAssertNil(Picker.pickRandomPlaylist(from: [emptyPlaylist]))
    }

    func testOnlyPlaylistWithTrackIsPicked() {
        let emptyPlaylist = Playlist.mock(name: "Empty",
                                          trackCount: 0)
        let nonEmptyPlaylist = Playlist.mock(name: "Non-empty",
                                             trackCount: 1)
        let playlists = [emptyPlaylist, nonEmptyPlaylist]

        XCTAssertEqual(Picker.pickRandomPlaylist(from: playlists),
                       nonEmptyPlaylist)
    }
}

private extension RandomPlaylistPickerTests {

    typealias Picker = RandomPlaylistPicker
}

private extension URL {

    static var mock: Self {
        URL(string: "www.example.com")!
    }
}
