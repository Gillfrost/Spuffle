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

class MockDataStore: DataStore {

    var data: Data?

    func getData() -> Data? {
        data
    }

    func setData(_ data: Data) {
        self.data = data
    }
}

protocol DataStore {

    func getData() -> Data?
    func setData(_ data: Data)
}

class PlaylistController {

    var includedPlaylists: AnyPublisher<[Playlist], Never> {
        filteredPlaylists(excluded: false)
    }

    var excludedPlaylists: AnyPublisher<[Playlist], Never> {
        filteredPlaylists(excluded: true)
    }

    private let dataStore: DataStore
    private let playlists = CurrentValueSubject<[Playlist]?, Never>(nil)
    private let excludedIdsSubject = CurrentValueSubject<Set<String>, Never>([])

    private var excludedIds: Set<String> {
        get {
            dataStore.getData()
                .flatMap { data in
                    try? JSONDecoder().decode(Set<String>.self, from: data)
                }
                ?? []
        }
        set {
            (try? JSONEncoder().encode(newValue))
                .map(dataStore.setData)
        }
    }

    init(dataStore: DataStore) {
        self.dataStore = dataStore
        excludedIdsSubject.send(excludedIds)
    }

    func load(_ playlists: [Playlist]) {
        self.playlists.send(playlists)
    }

    func exclude(_ playlist: Playlist) {
        excludedIds = excludedIds
            .union([Self.id(for: playlist)])

        excludedIdsSubject.send(excludedIds)
    }

    func include(_ playlist: Playlist) {
        excludedIds = excludedIds
            .subtracting([Self.id(for: playlist)])

        excludedIdsSubject.send(excludedIds)
    }

    static func id(for playlist: Playlist) -> String {
        playlist.name
    }

    private func filteredPlaylists(excluded: Bool) -> AnyPublisher<[Playlist], Never> {
        playlists
            .compactMap { $0 }
            .combineLatest(excludedIdsSubject)
            .map { playlists, excludedIds in
                playlists.filter { playlist in
                    excludedIds.contains(Self.id(for: playlist)) == excluded
                }
            }
            .eraseToAnyPublisher()
    }
}

struct Playlist: Equatable {
    let name: String
}
