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

    func testExcludePlaylist() {

        let includedExpectation = expectation(description: "included")
        let excludedExpectation = expectation(description: "excluded")

        let playlist = MockPlaylist(name: "Mock Playlist")

        let controller = self.controller()

        cancellable = controller.playlists
            .sink { playlists in
                XCTAssertEqual(playlists.count, 1)
                playlists.first?.isExcluded == true
                    ? excludedExpectation.fulfill()
                    : includedExpectation.fulfill()
            }

        controller.load([playlist])

        controller.exclude(id: playlist.name)

        wait(for: [includedExpectation, excludedExpectation],
             timeout: 0.1,
             enforceOrder: true)
    }

    func testIncludePlaylist() {

        let excludedExpectation = expectation(description: "excluded")
        let includedExpectation = expectation(description: "included")

        let playlist = MockPlaylist(name: "Mock Playlist")

        let controller = self.controller(initiallyExcludedPlaylists: [playlist.name])

        cancellable = controller.playlists
            .sink { playlists in
                XCTAssertEqual(playlists.count, 1)
                playlists.first?.isExcluded == true
                    ? excludedExpectation.fulfill()
                    : includedExpectation.fulfill()
            }

        controller.load([playlist])

        controller.include(id: playlist.name)

        wait(for: [excludedExpectation, includedExpectation],
             timeout: 0.1,
             enforceOrder: true)
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
        publishPlaylistsTrigger
            .map { [playlistsSubject, getExcludedIds] in
                playlistsSubject.value
                    .map { playlist in
                        PlaylistX(name: playlist.name,
                                  isExcluded: getExcludedIds().contains(playlist.name))
                    }
            }
            .eraseToAnyPublisher()
    }

    private let playlistsSubject = CurrentValueSubject<[MockPlaylist], Never>([])
    private let publishPlaylistsTrigger = PassthroughSubject<Void, Never>()

    private let getExcludedIds: () -> Set<String>
    private let setExcludedIds: (Set<String>) -> Void

    init(getExcludedIds: @escaping () -> Set<String>,
         setExcludedIds: @escaping (Set<String>) -> Void) {

        self.getExcludedIds = getExcludedIds
        self.setExcludedIds = setExcludedIds
    }

    func load(_ playlists: [MockPlaylist]) {
        playlistsSubject.send(playlists)
        publishPlaylistsTrigger.send(())
    }

    func exclude(id: String) {
        let excludedIds = getExcludedIds().union([id])
        setExcludedIds(excludedIds)
        publishPlaylistsTrigger.send(())
    }

    func include(id: String) {
        let excludedIds = getExcludedIds().subtracting([id])
        setExcludedIds(excludedIds)
        publishPlaylistsTrigger.send(())
    }
}

struct MockPlaylist {
    let name: String
}

struct PlaylistX {
    let name: String
    let isExcluded: Bool
}
