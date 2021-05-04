//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

struct RandomPlaylistPicker {

    private init() {}

    static func pickRandomPlaylist(from playlists: [Playlist]) -> Playlist? {

        let playlists = playlists.filter { $0.trackCount > 0 }

        guard !playlists.isEmpty else {
            return nil
        }

        let randomTrackIndex = UInt.random(in: 0...totalTrackCount(playlists))

        return playlist(containingTrackIndex: randomTrackIndex, playlists)
    }

    private static func totalTrackCount(_ playlists: [Playlist]) -> UInt {
        playlists
            .map { $0.trackCount }
            .reduce(0, +)
    }

    private static func playlist(containingTrackIndex index: UInt,
                                 _ playlists: [Playlist]) -> Playlist? {

        guard let aPlaylist = playlists.first else {
            return nil
        }

        return index <= aPlaylist.trackCount
            ? aPlaylist
            : playlist(containingTrackIndex: index - aPlaylist.trackCount,
                       Array(playlists.dropFirst()))
    }
}
