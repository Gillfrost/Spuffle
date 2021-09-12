//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import Foundation
import MediaPlayer
import Combine

final class MediaInfoCenter: ObservableObject {

    var track: Track? {
        didSet {
            artworkUrl = track?.artworkUrl
            setNowPlayingInfo()
        }
    }

    @Published private (set) var artwork: UIImage?

    private var artworkUrl: URL? {
        didSet {
            guard artworkUrl != oldValue else {
                return
            }
            artwork = nil
            guard let artworkUrl = artworkUrl else {
                return
            }
            URLSession.shared
                .dataTask(with: artworkUrl) { [weak self] (data, response, error) in
                    DispatchQueue.main.async {
                        self?.artwork = data.flatMap(UIImage.init)
                        self?.setNowPlayingInfo()
                    }
            }.resume()
        }
    }

    private func setNowPlayingInfo() {

        let artworkProperty = artwork.map { image in
            MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }.map {
            [MPMediaItemPropertyArtwork: $0]
        } ?? [:]

        MPNowPlayingInfoCenter.default().nowPlayingInfo = track.map {
            [
                MPMediaItemPropertyTitle: $0.name,
                MPMediaItemPropertyArtist: $0.artist,
                MPMediaItemPropertyPlaybackDuration: NSNumber(value: $0.duration),
                MPNowPlayingInfoPropertyPlaybackRate: 1.0
                ]
                .merging(artworkProperty) { $1 }
        }
    }
}
