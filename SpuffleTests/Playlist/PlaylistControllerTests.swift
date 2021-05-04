//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import XCTest
import Combine
@testable import Spuffle

final class PlaylistControllerTests: XCTestCase {

    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        cancellables = []
    }

    func testLoadPlaylists() {

        let expectation = self.expectation(description: #function)

        let controller = self.controller()
        let playlists = [Playlist.mock(name: "Mock Playlist 1"),
                         Playlist.mock(name: "Mock Playlist 2")]

        controller.includedPlaylists
            .combineLatest(controller.excludedPlaylists)
            .sink { includedPlaylists, excludedPlaylists in

                XCTAssertEqual(includedPlaylists, playlists)
                XCTAssertEqual(excludedPlaylists, [])

                expectation.fulfill()
            }
            .store(in: &cancellables)

        controller.load(playlists)

        waitForExpectations(timeout: 0.1)
    }

    func testInitiallyExcludedPlaylist() {

        let expectation = self.expectation(description: #function)

        let playlist = Playlist.mock()

        let dataStore = MockDataStore()

        self.controller(dataStore: dataStore).exclude(playlist)

        let controller = self.controller(dataStore: dataStore)

        controller.excludedPlaylists
            .sink { excludedPlaylists in

                XCTAssertEqual(excludedPlaylists, [playlist])

                expectation.fulfill()
            }
            .store(in: &cancellables)

        controller.load([playlist])

        waitForExpectations(timeout: 0.1)
    }

    func testExcludePlaylist() {

        let includedExpectation = expectation(description: "included")
        let excludedExpectation = expectation(description: "excluded")

        let playlist = Playlist.mock()

        let controller = self.controller()

        controller.includedPlaylists
            .sink { includedPlaylists in
                if includedPlaylists.contains(playlist) {
                    includedExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        controller.excludedPlaylists
            .sink { excludedPlaylists in
                if excludedPlaylists.contains(playlist) {
                    excludedExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        controller.load([playlist])

        controller.exclude(playlist)

        wait(for: [includedExpectation, excludedExpectation],
             timeout: 0.1,
             enforceOrder: true)
    }

    func testIncludePlaylist() {

        let excludedExpectation = expectation(description: "excluded")
        let includedExpectation = expectation(description: "included")

        let playlist = Playlist.mock()

        let dataStore = MockDataStore()

        self.controller(dataStore: dataStore).exclude(playlist)

        let controller = self.controller(dataStore: dataStore)

        controller.includedPlaylists
            .sink { includedPlaylists in
                if includedPlaylists.contains(playlist) {
                    includedExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        controller.excludedPlaylists
            .sink { excludedPlaylists in
                if excludedPlaylists.contains(playlist) {
                    excludedExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        controller.load([playlist])

        controller.include(playlist)

        wait(for: [excludedExpectation, includedExpectation],
             timeout: 0.1,
             enforceOrder: true)
    }
}

private extension PlaylistControllerTests {

    func controller(dataStore: DataStore = MockDataStore()) -> PlaylistController {
        PlaylistController(dataStore: dataStore)
    }
}

private extension Playlist {

    static func mock(name: String = "Mock Playlist") -> Playlist {
        Playlist(uri: URL(string: "www.example.com")!,
                 name: name,
                 trackCount: 0)
    }
}
