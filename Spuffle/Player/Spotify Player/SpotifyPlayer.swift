//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import Foundation
import AVFoundation
import Combine

final class SpotifyPlayer: Player {

    let state: AnyPublisher<PlayerState, Never>

    init(spotify: SpotifyController,
         playlistController: PlaylistController,
         token: AnyPublisher<String, Never>) {

        state = SpotifyPlayer.setup(spotify,
                                    playlistController,
                                    token: token)
    }
}

extension SpotifyPlayer {

    private static func setup(_ spotify: SpotifyController,
                              _ playlistController: PlaylistController,
                              token: AnyPublisher<String, Never>)
    -> AnyPublisher<PlayerState, Never> {

        let setup = CurrentValueSubject<Void, Never>(())

        return setup
            .flatMap {
                spotify
                    .start(withClientId: AppSecrets.clientId)
                    .flatMap {
                        load(spotify, playlistController, token: token)
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
                             _ playlistController: PlaylistController,
                             token: AnyPublisher<String, Never>)
    -> AnyPublisher<PlayerState, Never> {

        let load = CurrentValueSubject<Void, Never>(())

        return load
            .flatMap {
                token
                    .prefix(1)
                    .setFailureType(to: Error.self)
                    .flatMap { token in
                        loadPlaylists(spotify, playlistController, token: token)
                    }
                    .flatMap {
                        pauseLoaded(spotify, playlistController, token)
                            .setFailureType(to: Error.self)
                    }
                    .catch { Just(.error($0, retry: load.send)) }
                    .prepend(.loading)
            }
            .eraseToAnyPublisher()
    }

    private static func loadPlaylists(_ spotify: SpotifyController,
                                      _ playlistController: PlaylistController,
                                      token: String)
    -> AnyPublisher<Void, Error> {

        spotify
            .requestCurrentUser(withAccessToken: token)
            .flatMap { spotify.playlists(user: $0, token: token) }
            .map(playlistController.load)
            .eraseToAnyPublisher()
    }

    private static func pauseLoaded(_ spotify: SpotifyController,
                                    _ playlistController: PlaylistController,
                                    _ token: AnyPublisher<String, Never>)
    -> AnyPublisher<PlayerState, Never> {

        let login = CurrentValueSubject<Void, Never>(())

        let loginAndPlay = login
            .flatMap {
                token
                    .setFailureType(to: Error.self)
                    .flatMap(spotify.login)
                    .flatMap {
                        self.play(spotify, playlistController)
                    }
                    .replaceError(with: .error(SpotifyPlayerError.genericError,
                                               retry: login.send))
                    .prepend(.loading)
            }

        if spotify.isPlaying {
            return loginAndPlay
                .eraseToAnyPublisher()
        }

        let play = PassthroughSubject<Void, Never>()

        return play
            .prefix(1)
            .flatMap {
                loginAndPlay
            }
            .prepend(.paused(play: play.send))
            .eraseToAnyPublisher()
    }

    private static func play(_ spotify: SpotifyController,
                             _ playlistController: PlaylistController)
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
            .eraseToAnyPublisher()

        let togglePlay = PassthroughSubject<Bool, Error>()

        return activateAudioSession()
            .eraseToAnyPublisher()
            .merge(with: playNext.setFailureType(to: Error.self))
            .map {
                playRandomTrack(spotify, playlistController)
            }
            .switchToLatest()
            .map { track -> AnyPublisher<PlayerState, Error> in

                let playingState = PlayerState.playing(track: track,
                                                       pause: { togglePlay.send(false) },
                                                       skip: playNextSubject.send)

                let pausedState = PlayerState.paused(play: { togglePlay.send(true) })

                return togglePlay
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
                    .eraseToAnyPublisher()
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

    private static func playRandomTrack(_ spotify: SpotifyController,
                                        _ playlistController: PlaylistController)
    -> AnyPublisher<Track, Error> {

        randomPlaylist(playlistController)
            .prefix(1)
            .flatMap { playlist -> AnyPublisher<Track, Error> in

                let trackNumber = UInt.random(in: 0..<playlist.trackCount)

                return spotify.track
                    .prefix(1)
                    .map { track in
                        Track(name: track.name,
                              artist: track.artistName,
                              album: track.albumName)
                    }
                    .setFailureType(to: Error.self)
                    .combineLatest(spotify.playSpotifyURI(playlist.uri.absoluteString,
                                                          startingWith: trackNumber)
                                    .eraseToAnyPublisher())
                    .map { track, _ in track }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    private static func randomPlaylist(_ playlistController: PlaylistController)
    -> AnyPublisher<Playlist, Error> {

        playlistController.includedPlaylists
            .prefix(1)
            .setFailureType(to: Error.self)
            .map(RandomPlaylistPicker.pickRandomPlaylist)
            .tryMap { playlist -> Playlist in
                guard let playlist = playlist else {
                    throw SpotifyPlayerError.genericError
                }
                return playlist
            }
            .eraseToAnyPublisher()
    }
}
