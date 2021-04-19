//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import XCTest
import Combine
@testable import Spuffle

final class SpotifyPlayerTests: XCTestCase {

    private var cancellables: Set<AnyCancellable> = []

    func test_initialStateIsLoading() {

        verifyStates(.loading, for: player())
    }

    func testSetup_retryAfterErrorInStartRequest() {

        let startResults = futureFactory(.failure(error),
                                         .success(()))

        let mock = SpotifyMock(start: { _ in startResults() })

        verifyStates(.loading, .error, .loading, for: player(spotify: mock))
    }

    func testLoading_retryAfterErrorInUserRequest() {

        let requestCurrentUserResults = futureFactory(.failure(error),
                                                      .success(SPTUser()))

        let mock = SpotifyMock(
            requestCurrentUser: { _ in requestCurrentUserResults() })

        verifyStates(.loading, .error, .loaded, for: player(spotify: mock))
    }

    func testLoading_retryAfterErrorInPlaylistsRequest() {

        let playlistsResults = futureFactory(.failure(error),
                                             .success([SPTPartialPlaylist]()))

        let mock = SpotifyMock(
            playlists: { (_, _) in playlistsResults() })

        verifyStates(.loading, .error, .loaded, for: player(spotify: mock))
    }
}

private extension SpotifyPlayerTests {

    var error: Error { SpotifyPlayerError.genericError }

    enum State { case loading, error, loaded }

    func player(spotify: SpotifyMock = .init(),
                token: AnyPublisher<String, Never> = Just("").eraseToAnyPublisher()) -> SpotifyPlayer {

        SpotifyPlayer(spotify: spotify, token: token)
    }

    func futureFactory<Output, Failure>(_ sequentialResults: Result<Output, Failure>...) -> () -> Future<Output, Failure> {
        var count = 0
        return {
            defer { count += 1 }
            return Future { promise in
                guard count < sequentialResults.count else {
                    fatalError("More results demanded than were supplied")
                }
                promise(sequentialResults[count])
            }
        }
    }

    func verifyStates(_ states: State..., for player: Player) {

        let expectations = states.map { expectation(description: "\($0)") }

        player
            .state
            .prefix(states.count)
            .zip((0..<states.count).publisher)
            .sink { state, index in

                let expectation = expectations[index]

                switch (state, states[index]) {
                case (.loading, .loading), (.loaded, .loaded):
                    expectation.fulfill()
                case (.error(_, let retry), .error):
                    expectation.fulfill()
                    retry()
                default:
                    XCTFail("Expected state \(states[index]), but got \(state)")
                }
            }
            .store(in: &cancellables)

        wait(for: expectations,
             timeout: 0.1,
             enforceOrder: true)
    }
}
