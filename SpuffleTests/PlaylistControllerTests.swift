//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import XCTest
import Combine
@testable import Spuffle

final class PlaylistControllerTests: XCTestCase {

    private var cancellable: AnyCancellable?

    func testLoadPlaylists() {

        let expectation = self.expectation(description: #function)

        let controller = self.controller()
        let inputPlaylists = [MockPlaylist(name: "Mock Playlist 1"),
                              MockPlaylist(name: "Mock Playlist 2")]

        cancellable = controller.playlists
            .sink { outputPlaylists in
                XCTAssertEqual(outputPlaylists.map { $0.name },
                               inputPlaylists.map { $0.name })
                expectation.fulfill()
            }

        controller.load(inputPlaylists)

        waitForExpectations(timeout: 0.1)
    }

    func testInitiallyExcludedPlaylist() {

        let expectation = self.expectation(description: #function)

        let playlist = MockPlaylist(name: "Mock Playlist")

        let controller = self.controller(initiallyExcludedPlaylists: [playlist.name])

        cancellable = controller.playlists
            .sink { playlists in

                XCTAssertEqual(playlists.count, 1)
                XCTAssertEqual(playlists.first?.isExcluded, true)

                expectation.fulfill()
            }

        controller.load([playlist])

        waitForExpectations(timeout: 0.1)
    }
}

extension PlaylistControllerTests {

    private func controller(initiallyExcludedPlaylists: Set<String> = []) -> PlaylistController {

        var excludedIds: Set<String> = initiallyExcludedPlaylists

        return PlaylistController(getExcludedIds: { excludedIds },
                                  setExcludedIds: { excludedIds = $0 })
    }
}

struct PlaylistController {

    var playlists: AnyPublisher<[PlaylistX], Never> {
        playlistsSubject.eraseToAnyPublisher()
    }

    private let playlistsSubject = PassthroughSubject<[PlaylistX], Never>()

    private let getExcludedIds: () -> Set<String>
    private let setExcludedIds: (Set<String>) -> Void

    init(getExcludedIds: @escaping () -> Set<String>,
         setExcludedIds: @escaping (Set<String>) -> Void) {

        self.getExcludedIds = getExcludedIds
        self.setExcludedIds = setExcludedIds
    }

    func load(_ playlists: [MockPlaylist]) {

        let playlists = playlists.map {
            PlaylistX(name: $0.name,
                      isExcluded: getExcludedIds().contains($0.name))

        }
        playlistsSubject.send(playlists)
    }
}

struct MockPlaylist {
    let name: String
}

struct PlaylistX {
    let name: String
    let isExcluded: Bool
}
