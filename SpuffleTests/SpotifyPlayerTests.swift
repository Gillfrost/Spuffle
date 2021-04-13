//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import XCTest
import Combine
@testable import Spuffle

final class SpotifyPlayerTests: XCTestCase {

    private var cancellables: Set<AnyCancellable> = []

    func test_initialStateIsLoading() {

        let expectation = self.expectation(description: #function)

        player()
            .state
            .prefix(1)
            .sink { state in
                guard case .loading = state else {
                    XCTFail(state.description)
                    return
                }
                expectation.fulfill()
            }
            .store(in: &cancellables)

        waitForExpectations(timeout: 0)
    }

    func testSetup_retryAfterError() {

        let errorExpectation = expectation(description: "error")
        let loadingExpectation = expectation(description: "loading")

        let startResults = futureFactory(of: .failure(error), .success(()))

        let mock = SpotifyMock(start: { _ in startResults() })

        player(spotify: mock)
            .state
            .dropFirst()
            .prefix(2)
            .sink { state in
                switch state {
                case .error(_, let retry):
                    errorExpectation.fulfill()
                    retry()
                case .loading:
                    loadingExpectation.fulfill()
                default:
                    XCTFail(state.description)
                }
            }
            .store(in: &cancellables)

        wait(for: [errorExpectation, loadingExpectation], timeout: 0, enforceOrder: true)
    }

    func testLoadPlaylists_retryAfterError() {

        let errorExpectation = expectation(description: "error")
        let loadedExpectation = expectation(description: "loaded")

        let playlistsResults = futureFactory(of: .failure(error),
                                             .success([SPTPartialPlaylist]()))

        let mock = SpotifyMock(
            playlists: { (_, _) in playlistsResults() })

        player(spotify: mock)
            .state
            .dropFirst()
            .prefix(2)
            .sink { state in
                switch state {
                case .error(_, let retry):
                    errorExpectation.fulfill()
                    retry()
                case .loaded:
                    loadedExpectation.fulfill()
                default:
                    XCTFail(state.description)
                }
            }
            .store(in: &cancellables)

        wait(for: [errorExpectation, loadedExpectation], timeout: 1, enforceOrder: true)
    }
}

private extension SpotifyPlayerTests {

    var error: Error { SpotifyPlayerError.genericError }

    func player(spotify: SpotifyMock = .init(),
                token: AnyPublisher<String, Never> = Just("").eraseToAnyPublisher()) -> SpotifyPlayer {

        SpotifyPlayer(spotify: spotify, token: token)
    }

    func futureFactory<Output, Failure>(of results: Result<Output, Failure>...) -> () -> Future<Output, Failure> {
        var count = 0
        return {
            defer { count += 1 }
            return Future { promise in
                guard count < results.count else {
                    fatalError("More results demanded than were supplied")
                }
                promise(results[count])
            }
        }
    }
}
