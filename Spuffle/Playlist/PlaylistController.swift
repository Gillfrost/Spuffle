//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import Foundation
import Combine

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
