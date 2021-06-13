//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import Foundation

enum SpotifyPlayerError: String, LocalizedError {

    case setupError = "Struggling a little with setting up Spotify..."
    case audioActivationError = "Hmm. We can't play audio right now for some reason..."
    case genericError = "There's some unknown mischief going on..."

    var errorDescription: String? { rawValue }
}
