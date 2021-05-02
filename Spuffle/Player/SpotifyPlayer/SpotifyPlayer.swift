//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import Foundation
import AVFoundation
import Combine

final class SpotifyPlayer: Player {

    let state: AnyPublisher<PlayerState, Never>

    init(spotify: SpotifyController, token: AnyPublisher<String, Never>) {
        state = SpotifyPlayer.setup(spotify, token: token)
    }
}

extension SpotifyPlayer {

    static var playlistAdapter = { (sptPlaylist: SPTPartialPlaylist) in
        Playlist(uri: sptPlaylist.uri,
                 name: sptPlaylist.name,
                 trackCount: sptPlaylist.trackCount)
    }

    private static func setup(_ spotify: SpotifyController,
                              token: AnyPublisher<String, Never>) -> AnyPublisher<PlayerState, Never> {

        let setup = CurrentValueSubject<Void, Never>(())

        return setup
            .flatMap {
                spotify
                    .start(withClientId: AppSecrets.clientId)
                    .flatMap {
                        load(spotify, token: token)
                            .setFailureType(to: Error.self)
                    }
                    .replaceError(with: .error(SpotifyPlayerError.setupError,
                                               retry: setup.send))
                    .prepend(.loading)
            }
            .removeDuplicates { previous, next in
                if case .loading = previous, case .loading = next {
                    return true
                }
                return false
            }
            .eraseToAnyPublisher()
    }

    private static func load(_ spotify: SpotifyController,
                             token: AnyPublisher<String, Never>) -> AnyPublisher<PlayerState, Never> {

        let load = CurrentValueSubject<Void, Never>(())

        return load
            .flatMap {
                token
                    .prefix(1)
                    .setFailureType(to: Error.self)
                    .flatMap { token in
                        loadPlaylists(spotify, token: token)
                    }
                    .flatMap { playlists in
                        pauseLoaded(spotify, token, playlists)
                            .setFailureType(to: Error.self)
                    }
                    .catch { Just(.error($0, retry: load.send)) }
                    .prepend(.loading)
            }
            .eraseToAnyPublisher()
    }

    private static func loadPlaylists(_ spotify: SpotifyController,
                                      token: String) -> AnyPublisher<[Playlist], Error> {
        spotify
            .requestCurrentUser(withAccessToken: token)
            .flatMap { spotify.playlists(user: $0, token: token) }
            .map { $0.map(playlistAdapter) }
            .eraseToAnyPublisher()
    }

    private static func pauseLoaded(_ spotify: SpotifyController,
                                    _ token: AnyPublisher<String, Never>,
                                    _ playlists: [Playlist]) -> AnyPublisher<PlayerState, Never> {

        let login = CurrentValueSubject<Void, Never>(())

        let loginAndPlay = login
            .flatMap {
                token
                    .setFailureType(to: Error.self)
                    .flatMap(spotify.login)
                    .flatMap {
                        self.play(spotify, playlists)
                    }
                    .replaceError(with: .error(SpotifyPlayerError.genericError,
                                               retry: login.send))
                    .prepend(.loading)
            }

        if spotify.isPlaying {
            return loginAndPlay
                .prepend(.loaded(playlists: playlists))
                .eraseToAnyPublisher()
        }

        let play = PassthroughSubject<Void, Never>()

        return play
            .prefix(1)
            .flatMap {
                loginAndPlay
            }
            .prepend(.loaded(playlists: playlists),
                     .paused(play: play.send))
            .eraseToAnyPublisher()
    }

    private static func play(_ spotify: SpotifyController,
                             _ playlists: [Playlist])
    -> AnyPublisher<PlayerState, Error> {

        let playNextSubject = PassthroughSubject<Void, Never>()
        let playNext = playNextSubject
            .merge(
                with: spotify.event.filter {
                    guard case .didStopPlayingTrack = $0 else {
                        return false
                    }
                    return true
                }
                .map { _ in }
            )
            .setFailureType(to: Error.self)
            .flatMap {
                playRandomTrack(spotify, playlists)
            }
            .eraseToAnyPublisher()

        let togglePlay = PassthroughSubject<Bool, Error>()

        let playingState = PlayerState.playing(pause: { togglePlay.send(false) },
                                               skip: playNextSubject.send)

        let pausedState = PlayerState.paused(play: { togglePlay.send(true) })

        let start = spotify.isPlaying
            ? Result.success(()).publisher.eraseToAnyPublisher()
            : activateAudioSession().flatMap { playRandomTrack(spotify, playlists) }.eraseToAnyPublisher()

        return start
            .merge(with: playNext)
            .map {
                togglePlay
                    .removeDuplicates()
                    .flatMap { play in
                        spotify.setIsPlaying(play)
                        .map {
                            play
                                ? playingState
                                : pausedState
                        }
                    }
                    .prepend(playingState)
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }

    private static func activateAudioSession() -> Future<Void, Error> {
        Future { promise in
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true, options: [])
                promise(.success(()))

            } catch {
                promise(.failure(error))
            }
        }
    }

    private static func playRandomTrack(_ spotify: SpotifyController, _ playlists: [Playlist]) -> Future<Void, Error> {
        guard let playlist = pickRandomPlaylist(playlists) else {
            return Future {
                $0(.failure(SpotifyPlayerError.genericError))
            }
        }
        let trackNumber = UInt.random(in: 0..<playlist.trackCount)

        return spotify.playSpotifyURI(playlist.uri.absoluteString,
                                      startingWith: trackNumber)
    }

    private static func pickRandomPlaylist(_ playlists: [Playlist]) -> Playlist? {
        guard !playlists.isEmpty else {
            return nil
        }

        func playlist(containing trackIndex: UInt, playlistIndex: Int = 0) -> Playlist {
            let list = playlists[playlistIndex]

            return trackIndex <= list.trackCount
                ? list
                : playlist(containing: trackIndex - list.trackCount,
                           playlistIndex: playlistIndex + 1)
        }

        let includedTrackCount = playlists
            .map { $0.trackCount }
            .reduce(0, +)

        let randomTrackIndex = UInt.random(in: 0...includedTrackCount)

        return playlist(containing: randomTrackIndex)
    }
}
