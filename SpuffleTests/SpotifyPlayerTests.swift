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
            .sink { state in
                guard case .loading = state else {
                    XCTFail()
                    return
                }
                expectation.fulfill()
            }
            .store(in: &cancellables)

        waitForExpectations(timeout: 0)
    }

    func testSetup_retryAfterError() throws {

        let errorExpectation = expectation(description: "error")
        let successExpectation = expectation(description: #function)

        let startResults = futureFactory(of: .failure(error), .success(()))

        let mock = SpotifyMock(start: { _ in startResults() })

        player(spotify: mock)
            .state
            .dropFirst()
            .sink { state in
                switch state {
                case .error(_, let retry):
                    errorExpectation.fulfill()
                    retry()
                case .loading:
                    successExpectation.fulfill()
                default:
                    XCTFail()
                }
            }
            .store(in: &cancellables)

        wait(for: [errorExpectation, successExpectation], timeout: 0, enforceOrder: true)
    }
}

private extension SpotifyPlayerTests {

    var error: Error { SpotifyPlayerError.genericError }

    func player(spotify: SpotifyMock = .init(),
                token: AnyPublisher<String, Never> = Empty().eraseToAnyPublisher()) -> SpotifyPlayer {

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
