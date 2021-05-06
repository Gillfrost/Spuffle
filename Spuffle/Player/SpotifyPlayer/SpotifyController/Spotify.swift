//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import Foundation
import Combine

struct Spotify: SpotifyController {

    var event: AnyPublisher<SpotifyDelegate.Event, Never> {
        delegate.event
    }

    var track: AnyPublisher<SpotifyDelegate.Track, Never> {
        delegate.track.eraseToAnyPublisher()
    }

    var isPlaying: Bool {
        controller.playbackState.isPlaying
    }

    private var controller: SPTAudioStreamingController { .sharedInstance() }

    private let delegate = SpotifyDelegate()

    init() {
        controller.delegate = delegate
        controller.playbackDelegate = delegate
    }

    func start(withClientId: String) -> Future<Void, Error> {
        Log.info(#function)
        return Future { promise in
            do {
                try controller.start(withClientId: AppSecrets.clientId)
                promise(.success(()))

            } catch {
                promise(.failure(error))
            }
        }
    }

    func requestCurrentUser(withAccessToken token: String) -> Future<SPTUser, Error> {
        Future { promise in
            SPTUser.requestCurrentUser(withAccessToken: token) { error, result in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                guard let user = result as? SPTUser else {
                    assertionFailure()
                    promise(.failure(SpotifyPlayerError.genericError))
                    return
                }
                promise(.success(user))
            }
        }
    }

    func playlists(user: SPTUser,
                   token: String) -> Future<[SPTPartialPlaylist], Error> {
        Future { promise in
            SPTPlaylistList.playlists(forUser: user.canonicalUserName,
                                      withAccessToken: token) { error, result in
                playlistCallback(error: error,
                                 result: result,
                                 token: token,
                                 completion: promise)
            }
        }
    }

    private func playlistCallback(error: Error?,
                                  result: Any?,
                                  token: String,
                                  completion: @escaping (Result<[SPTPartialPlaylist], Error>) -> Void) {
        if let error = error {
            completion(.failure(error))
            return
        }
        guard let result = result else {
            Log.error("Nil result in playlist callback")
            completion(.failure(SpotifyPlayerError.genericError))
            return
        }
        guard let listPage = result as? SPTListPage else {
            Log.error("Playlist callback result is not SPTListPage")
            completion(.failure(SpotifyPlayerError.genericError))
            return
        }

        let playlists: [SPTPartialPlaylist] = listPage
            .tracksForPlayback()?
            .compactMap {
                guard let playlist = $0 as? SPTPartialPlaylist else {
                    Log.error("Expected all tracks for playback to be of type SPTPartialPlaylist")
                    return nil
                }
                return playlist
            }
            ?? []

        if listPage.hasNextPage {
            listPage.requestNextPage(withAccessToken: token) {
                playlistCallback(error: $0,
                                 result: $1,
                                 token: token,
                                 completion: {
                                    guard case .success(let morePlaylists) = $0 else {
                                        completion($0)
                                        return
                                    }
                                    completion(.success(playlists + morePlaylists))
                                 })
            }
        } else {
            completion(.success(playlists))
        }
    }

    func login(withAccessToken token: String) -> AnyPublisher<Void, Error> {
        Deferred {
            controller.loggedIn
                ? Result.success(()).publisher.eraseToAnyPublisher()
                : didLogin()
                .handleEvents(
                    receiveSubscription: { _ in
                        controller.login(withAccessToken: token)
                    })
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    private func didLogin() -> AnyPublisher<Void, Error> {
        delegate.event
            .setFailureType(to: Error.self)
            .tryFilter { event in
                if case .didReceiveError(let error) = event {
                    throw error
                } else if case .didLogin = event {
                    return true
                } else {
                    return false
                }
            }
            .prefix(1)
            .map { _ in }
            .eraseToAnyPublisher()
    }

    func playSpotifyURI(_ spotifyUri: String,
                        startingWith trackNumber: UInt) -> Future<Void, Error> {
        Future { promise in
            controller.playSpotifyURI(spotifyUri,
                                      startingWith: trackNumber,
                                      startingWithPosition: 0) { error in
                promise(error.map(Result.failure) ?? .success(()))
            }
        }
    }

    func setIsPlaying(_ play: Bool) -> Future<Void, Error> {
        Future { promise in
            controller.setIsPlaying(play) { error in
                promise(error.map(Result.failure) ?? .success(()))
            }
        }
    }
}
