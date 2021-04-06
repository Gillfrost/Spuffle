//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import Combine
@testable import Spuffle

final class SpotifyMock: SpotifyController {
    var isPlaying = false

    var event: AnyPublisher<SpotifyDelegate.Event, Never>

    private let _start: (String) -> Future<Void, Error>
    private let _requestCurrentUser: (String) -> Future<SPTUser, Error>
    private let _playlists: (SPTUser, String) -> Future<[SPTPartialPlaylist], Error>

    init(
        event: AnyPublisher<SpotifyDelegate.Event, Never> = Empty().eraseToAnyPublisher(),
        start: @escaping (String) -> Future<Void, Error> = { _ in
            Future { $0(.success(())) }
        },
        requestCurrentUser: @escaping (String) -> Future<SPTUser, Error> = { _ in
            Future { $0(.success(.init())) }
        },
        playlists: @escaping (SPTUser, String) -> Future<[SPTPartialPlaylist], Error> = { _, _ in
            Future { $0(.success([])) }
        }
    ) {
        self.event = event
        _start = start
        _requestCurrentUser = requestCurrentUser
        _playlists = playlists
    }

    func start(withClientId clientId: String) -> Future<Void, Error> {
        _start(clientId)
    }

    func requestCurrentUser(withAccessToken token: String) -> Future<SPTUser, Error> {
        _requestCurrentUser(token)
    }

    func playlists(user: SPTUser, token: String) -> Future<[SPTPartialPlaylist], Error> {
        _playlists(user, token)
    }

    func login(withAccessToken token: String) -> AnyPublisher<Void, Error> {
        Future { $0(.failure(SpotifyPlayerError.genericError)) }
            .eraseToAnyPublisher()
    }

    func playSpotifyURI(_ spotifyUri: String, startingWith trackNumber: UInt) -> Future<Void, Error> {
        Future { $0(.failure(SpotifyPlayerError.genericError)) }
    }

    func setIsPlaying(_ play: Bool) -> Future<Void, Error> {
        Future { $0(.failure(SpotifyPlayerError.genericError)) }
    }
}
