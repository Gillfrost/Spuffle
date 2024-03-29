//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import XCTest
import Combine
@testable import Spuffle

final class SpuffleViewModelTests: XCTestCase {

    // MARK: Is loading

    func test_isLoading_initially() {
        XCTAssert(viewModel().isLoading)
    }

    func test_isLoading_whenLoading() {
        XCTAssert(viewModel(state: .loading).isLoading)
    }

    func test_isNotLoading_whenPaused() {
        XCTAssertFalse(viewModel(state: .paused).isLoading)
    }

    func test_isNotLoading_whenPlaying() {
        XCTAssertFalse(viewModel(state: .playing).isLoading)
    }

    func test_isNotLoading_whenFailed() {
        XCTAssertFalse(viewModel(state: .error).isLoading)
    }

    // MARK: Can toggle play

    func test_canNotTogglePlay_initially() {
        XCTAssertFalse(viewModel().canTogglePlay)
    }

    func test_canNotTogglePlay_whenLoading() {
        XCTAssertFalse(viewModel(state: .loading).canTogglePlay)
    }

    func test_canTogglePlay_whenPaused() {
        XCTAssert(viewModel(state: .paused).canTogglePlay)
    }

    func test_canTogglePlay_whenPlaying() {
        XCTAssert(viewModel(state: .playing).canTogglePlay)
    }

    func test_canNotTogglePlay_whenFailed() {
        XCTAssertFalse(viewModel(state: .error).canTogglePlay)
    }

    // MARK: Is playing

    func test_isNotPlaying_initially() {
        XCTAssertFalse(viewModel().isPlaying)
    }

    func test_isNotPlaying_whenPaused() {
        XCTAssertFalse(viewModel(state: .paused).isPlaying)
    }

    func test_isPlaying_whenPlaying() {
        XCTAssert(viewModel(state: .playing).isPlaying)
    }

    func test_isNotPlaying_whenFailed() {
        XCTAssertFalse(viewModel(state: .error).isPlaying)
    }

    // MARK: Can skip

    func test_canNotSkip_initially() {
        XCTAssertFalse(viewModel().canSkip)
    }

    func test_canNotSkip_whenLoading() {
        XCTAssertFalse(viewModel(state: .loading).canSkip)
    }

    func test_canNotSkip_whenPaused() {
        XCTAssertFalse(viewModel(state: .paused).canSkip)
    }

    func test_canSkip_whenPlaying() {
        XCTAssert(viewModel(state: .playing).canSkip)
    }

    func test_canNotSkip_whenFailed() {
        XCTAssertFalse(viewModel(state: .error).canSkip)
    }

    // MARK: Track

    func test_trackIsNil_initially() {
        XCTAssertNil(viewModel().track)
    }

    func test_trackIsSet_whenPlaying() {
        let track = Track.unique()
        let state = PassthroughSubject<PlayerState, Never>()
        let viewModel = SpuffleViewModel(state: state.eraseToAnyPublisher())

        state.send(PlayerState.playing(track: track,
                                       pause: {},
                                       skip: {}))

        XCTAssertEqual(viewModel.track, track)
    }

    func test_trackIsNotChanged_whenPaused() {
        let track = Track.unique()
        let state = PassthroughSubject<PlayerState, Never>()
        let viewModel = SpuffleViewModel(state: state.eraseToAnyPublisher())

        state.send(PlayerState.playing(track: track,
                                       pause: {},
                                       skip: {}))

        state.send(.paused(play: {}))

        XCTAssertEqual(viewModel.track, track)
    }

    func test_trackIsNiled_whenLoading() {
        let state = PassthroughSubject<PlayerState, Never>()
        let viewModel = SpuffleViewModel(state: state.eraseToAnyPublisher())

        state.send(PlayerState.playing(track: .unique(),
                                       pause: {},
                                       skip: {}))
        state.send(.loading)

        XCTAssertNil(viewModel.track)
    }

    func test_trackIsNiled_whenFailed() {
        let state = PassthroughSubject<PlayerState, Never>()
        let viewModel = SpuffleViewModel(state: state.eraseToAnyPublisher())

        state.send(PlayerState.playing(track: .unique(),
                                       pause: {},
                                       skip: {}))
        state.send(.error(SpotifyPlayerError.genericError,
                          retry: {}))

        XCTAssertNil(viewModel.track)
    }
}

private extension SpuffleViewModelTests {

    enum State { case loading, paused, playing, error }

    func viewModel(state: State...) -> SpuffleViewModel {
        let stateSubject = PassthroughSubject<PlayerState, Never>()
        let viewModel = SpuffleViewModel(state: stateSubject.eraseToAnyPublisher())

        state.map(toPlayerState)
            .forEach(stateSubject.send)

        return viewModel
    }

    func toPlayerState(state: State) -> PlayerState {
        switch state {
        case .loading:
            return PlayerState.loading
        case .paused:
            return PlayerState.paused(play: {})
        case .playing:
            return PlayerState.playing(track: .init(name: .init(),
                                                    artist: .init(),
                                                    album: .init(),
                                                    duration: .init(),
                                                    artworkUrl: nil),
                                       pause: {},
                                       skip: {})
        case .error:
            return PlayerState.error(SpotifyPlayerError.genericError,
                                     retry: {})
        }
    }
}

private extension Track {

    static func unique() -> Track {
        .init(name: UUID().uuidString,
              artist: .init(),
              album: .init(),
              duration: .init(),
              artworkUrl: nil)
    }
}
