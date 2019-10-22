//  Copyright (c) 2019 André Gillfrost
//  Licensed under the MIT license

import UIKit
import AVFoundation

final class SpuffleViewController: UIViewController {

    private enum State {
        case initial, loaded, playing, paused
    }

    private struct Playlist {
        let uri: URL
        let name: String
        let trackCount: UInt

        private (set) var excluded = false

        init(uri: URL, name: String, trackCount: UInt) {
            self.uri = uri
            self.name = name
            self.trackCount = trackCount
        }

        mutating func toggleExcluded() {
            excluded.toggle()
        }
    }

    var session: SPTSession?

    private var controller: SPTAudioStreamingController {
        return .sharedInstance()
    }

    private var state = State.initial {
        didSet {
            setButtons()
        }
    }

    @IBOutlet weak private var playButton: UIButton!
    @IBOutlet weak private var skipButton: UIButton!
    @IBOutlet weak private var tableView: UITableView!
    @IBOutlet weak private var listHeightConstraint: NSLayoutConstraint!

    private var listPanStartingHeight: CGFloat = 0

    private var minimumListHeight: CGFloat {
        return view.safeAreaInsets.bottom + tableView.frame.minY
    }

    private var maximumListHeight: CGFloat {
        let max = view.frame.height - view.safeAreaInsets.top
        let preferred = minimumListHeight + tableView.contentSize.height
        return min(max, preferred)
    }

    private var playlists: [Playlist] = [] {
        didSet {
            if state == .initial {
                state = .loaded
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAudioController()
        tableView.tableFooterView = UIView()
        loadPlaylists()
        setButtons()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        listHeightConstraint.constant = minimumListHeight
        animateLayout()
    }

    deinit {
        try? AVAudioSession.sharedInstance().setActive(false, options: [])
    }

    private func setupAudioController() {
        controller.delegate = self
        do {
            try controller.start(withClientId: SPTAuth.defaultInstance().clientID!)
            try AVAudioSession.sharedInstance().setCategory(.playback)
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }

    // MARK: - Playback

    @IBAction private func togglePlay() {
        state == .playing ? pause() : play()
    }

    private func setButtons() {
        let title = state == .playing ? "||" : "▷"
        playButton.setTitle(title, for: .normal)
        playButton.isHidden = state == .initial

        skipButton.isHidden = state != .playing
    }

    private var playingList: Playlist? = nil

    @IBAction private func play() {
        guard let playlist = playlists.filter({ !$0.excluded }).randomElement() else {
            assertionFailure()
            return
        }
        playingList = playlist

        defer { state = .playing }
        guard controller.loggedIn else {
            login()
            return
        }
        switch state {
        case .initial:
            assertionFailure()
        case .playing, .loaded:
            controller.playSpotifyURI(playlist.uri.absoluteString,
                                      startingWith: UInt.random(in: 0..<playlist.trackCount),
                                      startingWithPosition: 0) { error in
                                        if let error = error {
                                            assertionFailure(error.localizedDescription)
                                        }
            }
        case .paused:
            controller.setIsPlaying(true) { error in
                if let error = error {
                    assertionFailure(error.localizedDescription)
                }
            }
        }
    }

    private func login() {
        guard let token = session?.accessToken else {
            assertionFailure()
            return
        }
        controller.login(withAccessToken: token)
    }

    private func pause() {
        controller.setIsPlaying(false) { error in
            if let error = error {
                assertionFailure(error.localizedDescription)
            }
        }
        state = .paused
    }

    // MARK: - Playlists

    @IBAction func panList(_ pan: UIPanGestureRecognizer) {
        switch pan.state {
        case .began:
            listPanStartingHeight = listHeightConstraint.constant
        case .changed:
            listHeightConstraint.constant = listPanStartingHeight - pan.translation(in: view).y
        case .ended:
            let endHeight: CGFloat
            let velocity = pan.velocity(in: view).y
            if abs(velocity) > 200 {
                endHeight = velocity < 0 ? maximumListHeight : minimumListHeight
            } else {
                let currentHeight = listHeightConstraint.constant
                let halfMaximumHeight = (maximumListHeight - minimumListHeight) / 2
                endHeight = currentHeight < halfMaximumHeight
                    ? minimumListHeight
                    : maximumListHeight
            }
            listHeightConstraint.constant = endHeight
            animateLayout()
        default:
            break
        }
    }

    private func animateLayout() {
        UIView.animate(withDuration: 0.25,
                       animations: { self.view.layoutIfNeeded() })
    }

    private func loadPlaylists() {
        guard let token = session?.accessToken else {
            // TODO: - Dismiss
            return
        }
        getPlaylists(token: token) { [weak self] in
            self?.playlists = $0
            self?.tableView.reloadData()
        }
    }

    private func getPlaylists(token: String, completion: @escaping ([Playlist]) -> Void) {
        SPTUser.requestCurrentUser(withAccessToken: token) { [weak self] error, result in
            guard let user = result as? SPTUser else {
                return
            }
            self?.getPlaylists(user: user.canonicalUserName, token: token, completion: completion)
        }
    }

    private func getPlaylists(user: String, token: String, completion: @escaping ([Playlist]) -> Void) {
        SPTPlaylistList.playlists(forUser: user,
                                  withAccessToken: token) { [weak self] (error, result) in
                                    self?.playlistCallback(error: error, result: result, token: token, completion: completion)
        }
        return
    }

    private func playlistCallback(error: Error?, result: Any?, token: String, completion: @escaping ([Playlist]) -> Void) {
        guard let listPage = result as? SPTListPage else {
            fatalError()
        }

        let playlists = listPage.tracksForPlayback()?
            .compactMap { $0 as? SPTPartialPlaylist }
            .map {
                Playlist(uri: $0.playableUri,
                         name: $0.name,
                         trackCount: $0.trackCount)

            } ?? []

        if listPage.hasNextPage {
            listPage.requestNextPage(withAccessToken: token) { [weak self] in
                self?.playlistCallback(error: $0, result: $1, token: token, completion: { completion(playlists + $0) })
            }
        } else {
            completion(playlists)
        }
    }
}

extension SpuffleViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlists.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "playlist_cell", for: indexPath)

        configure(cell, for: indexPath)

        return cell
    }

    private func configure(_ cell: UITableViewCell, for indexPath: IndexPath) {
        let playlist = playlists[indexPath.row]
        cell.textLabel?.text = playlist.name
        cell.textLabel?.font = .systemFont(ofSize: 17, weight: playlist.excluded ? .regular : .semibold)
        cell.textLabel?.textAlignment = playlist.excluded ? .right : .left
    }
}

extension SpuffleViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        playlists[indexPath.row].toggleExcluded()

        tableView.cellForRow(at: indexPath).map {
            configure($0, for: indexPath)
        }
    }
}

extension SpuffleViewController: SPTAudioStreamingDelegate {

    func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController) {
        try? AVAudioSession.sharedInstance().setActive(true, options: [])
        if state == .playing {
            play()
        }
    }
}
