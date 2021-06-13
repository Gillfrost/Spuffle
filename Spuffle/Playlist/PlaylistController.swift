//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import Foundation
import Combine

protocol InputPlaylist {

    var uri: URL { get }
    var name: String { get }
    var trackCount: UInt { get }
}

class PlaylistController {

    var playlists: AnyPublisher<[Playlist], Never> {
        playlistsSubject
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }

    var includedPlaylists: AnyPublisher<[Playlist], Never> {
        playlists
            .map { playlists in
                playlists
                    .reduce(Just([Playlist]()).eraseToAnyPublisher()) { playlists, playlist in
                        playlists
                            .combineLatest(playlist.isExcluded)
                            .map { playlists, isExcluded in
                                isExcluded
                                    ? playlists
                                    : playlists + [playlist]
                            }
                            .eraseToAnyPublisher()
                    }
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }

    private let dataStore: DataStore
    private let playlistsSubject = CurrentValueSubject<[Playlist]?, Never>(nil)
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

    func load(_ inputPlaylists: [InputPlaylist]) {
        let playlists = inputPlaylists
            .map { inputPlaylist -> Playlist in

                let id = inputPlaylist.uri.absoluteString

                let isExcluded = excludedIdsSubject
                    .map { $0.contains(id) }
                    .eraseToAnyPublisher()

                return Playlist(uri: inputPlaylist.uri,
                                name: inputPlaylist.name,
                                trackCount: inputPlaylist.trackCount,
                                isExcluded: isExcluded,
                                toggleIsExcluded: { [weak self] in self?.toggleIsExcluded(id: id) })
            }

        self.playlistsSubject.send(playlists)
    }

    private func toggleIsExcluded(id: String) {
        excludedIds.formSymmetricDifference([id])
        excludedIdsSubject.send(excludedIds)
    }
}
