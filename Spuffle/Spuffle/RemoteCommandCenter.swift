//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import Foundation
import Combine
import MediaPlayer

final class RemoteCommandCenter {

    private let togglePlay: () -> Bool
    private let skip: () -> Bool

    private var commandCenter: MPRemoteCommandCenter {
        return .shared()
    }
    private var playOrPauseControlSubscription: Any?
    private var togglePlayControlSubscription: Any?
    private var nextControlSubscription: Any?

    private var cancellable: AnyCancellable?

    init(isPlaying: AnyPublisher<Bool, Never>, togglePlay: @escaping () -> Bool, skip: @escaping () -> Bool) {
        self.togglePlay = togglePlay
        self.skip = skip

        cancellable = isPlaying.sink { [weak self] isPlaying in
            self?.removeControlSubscriptions()
            self?.setupControlSubscriptions(isPlaying: isPlaying)
        }
    }

    private func removeControlSubscriptions() {
        playOrPauseControlSubscription.map(
            commandCenter.togglePlayPauseCommand.removeTarget
        )
        playOrPauseControlSubscription = nil

        togglePlayControlSubscription.map(
            commandCenter.togglePlayPauseCommand.removeTarget
        )
        togglePlayControlSubscription = nil

        nextControlSubscription.map(
            commandCenter.nextTrackCommand.removeTarget
        )
        nextControlSubscription = nil
    }

    private func setupControlSubscriptions(isPlaying: Bool) {

        let playOrPauseCommand = isPlaying
            ? commandCenter.pauseCommand
            : commandCenter.playCommand

        playOrPauseControlSubscription = playOrPauseCommand
            .addTarget { [togglePlay] event in
                Log.info("MPRemote: \(isPlaying ? "pauseCommand" : "playCommand")")

                return togglePlay()
                    ? .success
                    : .commandFailed
        }

        togglePlayControlSubscription = commandCenter
            .togglePlayPauseCommand
            .addTarget { [togglePlay] event in
                Log.info("MPRemote: togglePlayPauseCommand")

                return togglePlay()
                    ? .success
                    : .commandFailed
            }

        if isPlaying {
            nextControlSubscription = commandCenter
                .nextTrackCommand
                .addTarget { [skip] event in
                    Log.info("MPRemote: nextTrackCommand")

                    return skip()
                        ? .success
                        : .commandFailed
            }
        }
    }
}
