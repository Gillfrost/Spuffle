//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import Foundation
import Combine

final class SpotifyDelegate: NSObject {

    enum Event {
        case didLogin
        case didReceiveError(Error)
        case didStopPlayingTrack
    }

    var event: AnyPublisher<Event, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    var track: AnyPublisher<SPTPlaybackTrack, Never> {
        trackSubject.eraseToAnyPublisher()
    }

    private let eventSubject = PassthroughSubject<Event, Never>()
    private let trackSubject = PassthroughSubject<SPTPlaybackTrack, Never>()
}

extension SpotifyDelegate: SPTAudioStreamingDelegate {

    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didReceiveError error: Error) {
        Log.error(error)
        eventSubject.send(.didReceiveError(error))
    }

    func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController) {
        Log.info(#function)
        eventSubject.send(.didLogin)
    }

    func audioStreamingDidLogout(_ audioStreaming: SPTAudioStreamingController) {
        Log.info(#function)
    }

    func audioStreamingDidEncounterTemporaryConnectionError(_ audioStreaming: SPTAudioStreamingController) {
        Log.info(#function)
    }

    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didReceiveMessage message: String) {
        Log.info(#function)
    }

    func audioStreamingDidDisconnect(_ audioStreaming: SPTAudioStreamingController) {
        Log.info(#function)
    }

    func audioStreamingDidReconnect(_ audioStreaming: SPTAudioStreamingController) {
        Log.info(#function)
    }
}

extension SpotifyDelegate: SPTAudioStreamingPlaybackDelegate {

    // MARK: - Playback delegate -

    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didReceive event: SpPlaybackEvent) {
        Log.info("Spotify event: \(event)")
    }

    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didChangePosition position: TimeInterval) {
//        Log.info(#function)
    }

    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didChangePlaybackStatus isPlaying: Bool) {
        Log.info("Spotify did change status is playing: \(isPlaying)")
    }

    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didSeekToPosition position: TimeInterval) {
        Log.info("Spotify did seek to position \(position)")
    }

    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didChangeVolume volume: SPTVolume) {
        Log.info("Spotify did change volume")
    }

    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didChangeShuffleStatus enabled: Bool) {
        Log.info("Spotify did change shuffle status enabled: \(enabled)")
    }

    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didChangeRepeatStatus repeateMode: SPTRepeatMode) {
        Log.info("Spotify did change repeat status")
    }

    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didChange metadata: SPTPlaybackMetadata) {
        Log.info("Spotify did change metadata. current: \(metadata.currentTrack?.name ?? "")")
        metadata.currentTrack.map(trackSubject.send)
    }

    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didStartPlayingTrack trackUri: String) {
        Log.info("Spotify did start playing track")
    }

    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didStopPlayingTrack trackUri: String) {
        Log.info("Spotify did stop playing track")
        eventSubject.send(.didStopPlayingTrack)
    }

    func audioStreamingDidSkip(toNextTrack audioStreaming: SPTAudioStreamingController) {
        Log.info("Spotify did skip to next track")
    }

    func audioStreamingDidSkip(toPreviousTrack audioStreaming: SPTAudioStreamingController) {
        Log.info("Spotify did skip to previous track")
    }

    func audioStreamingDidBecomeActivePlaybackDevice(_ audioStreaming: SPTAudioStreamingController) {
        Log.info("Spotify did become active playback device")
    }

    func audioStreamingDidBecomeInactivePlaybackDevice(_ audioStreaming: SPTAudioStreamingController) {
        Log.info("Spotify did become inactive playback device")
    }

    func audioStreamingDidLosePermission(forPlayback audioStreaming: SPTAudioStreamingController) {
        Log.info("Spotify did lose permission")
    }

    func audioStreamingDidPopQueue(_ audioStreaming: SPTAudioStreamingController) {
        Log.info("Spotify did pop queue")
    }
}
