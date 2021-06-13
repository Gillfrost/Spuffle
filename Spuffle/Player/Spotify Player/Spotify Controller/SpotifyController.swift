//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import Foundation
import Combine

protocol SpotifyController {

    var isPlaying: Bool { get }

    var event: AnyPublisher<SpotifyDelegate.Event, Never> { get }
    var track: AnyPublisher<SPTPlaybackTrack, Never> { get }

    func start(withClientId: String) -> Future<Void, Error>
    func requestCurrentUser(withAccessToken token: String) -> Future<SPTUser, Error>
    func playlists(user: SPTUser,
                   token: String) -> Future<[SPTPartialPlaylist], Error>
    func login(withAccessToken token: String) -> AnyPublisher<Void, Error>
    func playSpotifyURI(_ spotifyUri: String,
                        startingWith trackNumber: UInt) -> Future<Void, Error>
    func setIsPlaying(_ play: Bool) -> Future<Void, Error>
}
