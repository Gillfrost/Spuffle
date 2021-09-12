//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import Combine

final class SpuffleViewModel: ObservableObject {

    @Published private (set) var isLoading = true
    @Published private (set) var canTogglePlay = false
    @Published private (set) var isPlaying = false
    @Published private (set) var canSkip = false

    @Published private (set) var track: Track?

    @Published private (set) var togglePlay: (() -> Void)?
    @Published private (set) var skip: (() -> Void)?

    @Published private (set) var error: SpuffleError?

    init(state: AnyPublisher<PlayerState, Never>) {
        let state = state.share()

        state.map {
            guard case .loading = $0 else {
                return false
            }
            return true
        }
        .removeDuplicates()
        .assign(to: &$isLoading)

        state.map {
            switch $0 {
            case .paused, .playing:
                return true
            case .loading, .error:
                return false
            }
        }
        .removeDuplicates()
        .assign(to: &$canTogglePlay)

        state.map {
            guard case .playing = $0 else {
                return false
            }
            return true
        }
        .removeDuplicates()
        .assign(to: &$isPlaying)

        state.map {
            guard case .playing = $0 else {
                return false
            }
            return true
        }
        .removeDuplicates()
        .assign(to: &$canSkip)

        state.filter {
            if case .paused = $0 {
                return false
            }
            return true
        }
        .map {
            guard case .playing(track: let track, _, _) = $0 else {
                return nil
            }
            return track
        }
        .removeDuplicates()
        .assign(to: &$track)

        state.map {
            switch $0 {
            case .paused(let togglePlay),
                 .playing(track: _, pause: let togglePlay, skip: _):

                return togglePlay

            case .loading, .error:
                return nil
            }
        }
        .assign(to: &$togglePlay)

        state.map {
            guard case .playing(track: _, pause: _, skip: let skip) = $0 else {
                return nil
            }
            return skip
        }
        .assign(to: &$skip)

        state.map {
            guard case .error(let error, let retry) = $0 else {
                return nil
            }
            return SpuffleError(error: error, retry: retry)
        }
        .assign(to: &$error)
    }
}
