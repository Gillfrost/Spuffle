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

        controller.playlists
            .sink { outputPlaylists in

                XCTAssertEqual(outputPlaylists, playlists)

                expectation.fulfill()
            }
            .store(in: &cancellables)

        controller.load(playlists)

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

                    DispatchQueue.main.async {
                        includedPlaylists.first?.toggleIsExcluded()
                    }

                } else {
                    excludedExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        controller.load([playlist])

        wait(for: [includedExpectation, excludedExpectation],
             timeout: 0.1,
             enforceOrder: true)
    }

    func testInitiallyExcludedPlaylist() {

        let includedExpectation = self.expectation(description: "included")
        let excludedExpectation = self.expectation(description: "excluded")

        let playlist = Playlist.mock()

        let dataStore = MockDataStore()

        let controller1 = controller(dataStore: dataStore)

        controller1.load([playlist])
        controller1.includedPlaylists
            .sink { playlists in
                playlists.first?.toggleIsExcluded()
                includedExpectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [includedExpectation], timeout: 0.1)

        let controller2 = self.controller(dataStore: dataStore)

        controller2.includedPlaylists
            .sink { includedPlaylists in

                if includedPlaylists.contains(playlist) {
                    XCTFail("Playlist should be excluded")
                }

                excludedExpectation.fulfill()
            }
            .store(in: &cancellables)

        controller2.load([playlist])

        wait(for: [excludedExpectation], timeout: 0.1)
    }
}

private extension PlaylistControllerTests {

    func controller(dataStore: DataStore = MockDataStore()) -> PlaylistController {
        PlaylistController(dataStore: dataStore)
    }
}

extension Playlist: InputPlaylist {

    static func mock(name: String = "Mock Playlist",
                     trackCount: UInt = 0) -> Playlist {

        Playlist(uri: URL(string: "www.example.com")!,
                 name: name,
                 trackCount: trackCount,
                 isExcluded: Just(false).eraseToAnyPublisher(),
                 toggleIsExcluded: {})
    }
}

extension Playlist: Equatable {

    public static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        lhs.uri == rhs.uri
            && lhs.name == rhs.name
            && lhs.trackCount == rhs.trackCount
    }
}
