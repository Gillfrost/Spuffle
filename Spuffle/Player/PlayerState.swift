//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import Foundation

enum PlayerState {

    case loading
    case paused(play: () -> Void)
    case playing(track: Track, pause: () -> Void, skip: () -> Void)
    case error(Error, retry: () -> Void)
}

#if DEBUG
extension PlayerState: CustomStringConvertible {

    var description: String {
        switch self {
        case .loading:
            return "PlayerState.loading"
        case .paused:
            return "PlayerState.paused"
        case .playing:
            return "PlayerState.playing"
        case .error(let error, _):
            return "PlayerState.error \(error.localizedDescription)"
        }
    }
}
#endif
