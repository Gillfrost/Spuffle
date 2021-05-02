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
        let playlists = [Playlist(name: "Mock Playlist 1"),
                         Playlist(name: "Mock Playlist 2")]

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

        let playlist = Playlist(name: "Mock Playlist")

        let controller = self.controller(initiallyExcludedPlaylists: [playlist])

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

        let playlist = Playlist(name: "Mock Playlist")

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

        let playlist = Playlist(name: "Mock Playlist")

        let controller = self.controller(initiallyExcludedPlaylists: [playlist])

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

extension PlaylistControllerTests {

    private func controller(initiallyExcludedPlaylists: [Playlist] = []) -> PlaylistController {

        var excludedIds: Set<String> = Set(initiallyExcludedPlaylists.map { $0.name })

        return PlaylistController(getExcludedIds: { excludedIds },
                                  setExcludedIds: { excludedIds = $0 })
    }
}

struct PlaylistController {

    var includedPlaylists: AnyPublisher<[Playlist], Never> {
        filteredPlaylists(excluded: false)
    }

    var excludedPlaylists: AnyPublisher<[Playlist], Never> {
        filteredPlaylists(excluded: true)
    }

    private let playlists = CurrentValueSubject<[Playlist]?, Never>(nil)
    private let excludedIds: CurrentValueSubject<Set<String>, Never>

    private let getExcludedIds: () -> Set<String>
    private let setExcludedIds: (Set<String>) -> Void

    init(getExcludedIds: @escaping () -> Set<String>,
         setExcludedIds: @escaping (Set<String>) -> Void) {

        self.getExcludedIds = getExcludedIds
        self.setExcludedIds = setExcludedIds
        self.excludedIds = .init(getExcludedIds())
    }

    func load(_ playlists: [Playlist]) {
        self.playlists.send(playlists)
    }

    func exclude(_ playlist: Playlist) {
        let excludedIds = getExcludedIds().union([Self.id(playlist)])
        setExcludedIds(excludedIds)
        self.excludedIds.send(excludedIds)
    }

    func include(_ playlist: Playlist) {
        let excludedIds = getExcludedIds().subtracting([Self.id(playlist)])
        setExcludedIds(excludedIds)
        self.excludedIds.send(excludedIds)
    }

    private static func id(_ playlist: Playlist) -> String {
        playlist.name
    }

    private func filteredPlaylists(excluded: Bool) -> AnyPublisher<[Playlist], Never> {
        playlists
            .compactMap { $0 }
            .combineLatest(excludedIds)
            .map { playlists, excludedIds in
                playlists.filter { playlist in
                    excludedIds.contains(Self.id(playlist)) == excluded
                }
            }
            .eraseToAnyPublisher()
    }
}

struct Playlist: Equatable {
    let name: String
}
