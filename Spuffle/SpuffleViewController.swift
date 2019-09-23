//  Copyright (c) 2019 André Gillfrost
//  Licensed under the MIT license

import UIKit

final class SpuffleViewController: UIViewController {

    var session: SPTSession?

    private var playlists: [String] = [] {
        didSet {
            print(playlists)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadPlaylists()
    }

    private func loadPlaylists() {
        guard let token = session?.accessToken else {
            // TODO: - Dismiss
            return
        }
        getPlaylists(token: token) { [weak self] in
            self?.playlists = $0
        }
    }

    private func getPlaylists(token: String, completion: @escaping ([String]) -> Void) {
        SPTUser.requestCurrentUser(withAccessToken: token) { [weak self] error, result in
            guard let user = result as? SPTUser else {
                return
            }
            self?.getPlaylists(user: user.canonicalUserName, token: token, completion: completion)
        }
    }

    private func getPlaylists(user: String, token: String, completion: @escaping ([String]) -> Void) {
        SPTPlaylistList.playlists(forUser: user,
                                  withAccessToken: token) { [weak self] (error, result) in
                                    self?.playlistCallback(error: error, result: result, token: token, completion: completion)
        }
        return
    }

    private func playlistCallback(error: Error?, result: Any?, token: String, completion: @escaping ([String]) -> Void) {
        guard let listPage = result as? SPTListPage else {
            fatalError()
        }

        let playlists = listPage.tracksForPlayback()?
            .compactMap { $0 as? SPTPartialPlaylist }
            .map { $0.name } ?? []

        if listPage.hasNextPage {
            listPage.requestNextPage(withAccessToken: token) { [weak self] in
                self?.playlistCallback(error: $0, result: $1, token: token, completion: { completion(playlists + $0) })
            }
        } else {
            completion(playlists)
        }
    }
}
