//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import Foundation

enum PlayerState {

    case loading
    case loaded(playlists: [Playlist])
    case paused(play: () -> Void)
    case playing(pause: () -> Void, skip: () -> Void)
    case error(Error, retry: () -> Void)
}

#if DEBUG
extension PlayerState: CustomStringConvertible {

    var description: String {
        switch self {
        case .loading:
            return "PlayerState.loading"
        case .loaded(playlists: let playlists):
            return "PlayerState.loaded \(playlists.count) playlists"
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
