//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import Foundation

extension SpPlaybackEvent: CustomStringConvertible {

    public var description: String {
        switch self {
        case .SPPlaybackEventAudioFlush:
            return "AudioFlush"
        case .SPPlaybackNotifyAudioDeliveryDone:
            return "AudioDeliveryDone"
        case .SPPlaybackNotifyBecameActive:
            return "BecameActive"
        case .SPPlaybackNotifyBecameInactive:
            return "BecameInactive"
        case .SPPlaybackNotifyContextChanged:
            return "ContextChanged"
        case .SPPlaybackNotifyLostPermission:
            return "LostPermission"
        case .SPPlaybackNotifyMetadataChanged:
            return "MetadataChanged"
        case .SPPlaybackNotifyNext:
            return "Next"
        case .SPPlaybackNotifyPause:
            return "Pause"
        case .SPPlaybackNotifyPlay:
            return "Play"
        case .SPPlaybackNotifyPrev:
            return "Prev"
        case .SPPlaybackNotifyRepeatOff:
            return "RepeatOff"
        case .SPPlaybackNotifyRepeatOn:
            return "RepeatOn"
        case .SPPlaybackNotifyTrackChanged:
            return "TrackChanged"
        case .SPPlaybackNotifyShuffleOn:
            return "ShuffleOn"
        case .SPPlaybackNotifyShuffleOff:
            return "ShuffleOff"
        case .SPPlaybackNotifyTrackDelivered:
            return "TrackDelivered"
        @unknown default:
            assertionFailure()
            return "Unknown"
        }
    }
}
