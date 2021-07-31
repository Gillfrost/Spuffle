//  Copyright (c) 2019 André Gillfrost
//  Licensed under the MIT license

import UIKit
import MediaPlayer
import Combine
import SwiftUI

final class SpuffleViewController: UIViewController {

    private enum State {
        case initial, playing, paused
    }

    var session: SPTSession?

    private var state = State.initial {
        didSet {
            setButtonsAndMetadataVisibility()
        }
    }

    private var track: Track? {
        didSet {
            trackLabel.text = track.map { "\"\($0.name)\"" }
            artistLabel.text = track.map { $0.artist }
            artworkUrl = track?.artworkUrl
            setNowPlayingInfo()
        }
    }

    private func setNowPlayingInfo() {
        let artworkProperty = artwork.map { image in
            MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }.map { [MPMediaItemPropertyArtwork: $0] }
            ?? [:]
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
                    }
            }.resume()
        }
    }

    private var artwork: UIImage? {
        didSet {
            guard let artwork = artwork else {
                coverImage.image = nil
                return
            }
            coverImage.image = artwork
            setNowPlayingInfo()
        }
    }

    @IBOutlet weak private var errorLabel: UILabel!
    @IBOutlet weak private var tryAgainButton: UIButton!
    @IBOutlet weak private var playerContainer: UIView!
    @IBOutlet weak private var trackLabel: UILabel!
    @IBOutlet weak private var artistLabel: UILabel!
    @IBOutlet weak private var coverImage: UIImageView!
    @IBOutlet weak private var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak private var playButton: UIButton!
    @IBOutlet weak private var skipButton: UIButton!
    @IBOutlet weak private var playlistHandle: UIView!
    @IBOutlet weak private var bluetoothLabel: UILabel!
    @IBOutlet weak private var tableView: UITableView!
    @IBOutlet weak private var includeLabel: UILabel!
    @IBOutlet weak private var excludeLabel: UILabel!
    @IBOutlet weak private var safeAreaBottomCover: UIView!
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
            tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()

        playlistController.playlists
            .sink { [weak self] playlists in
                self?.playlists = playlists
            }
            .store(in: &cancellables)

        let player: Player? = session.map { session in
            let token = Just(session.accessToken)
                .eraseToAnyPublisher()

            return SpotifyPlayer(spotify: Spotify(),
                                 playlistController: playlistController,
                                 token: token)
        }

        player?.state.sink { [weak self] state in
            switch state {
            case .loading:
                self?.playButton.isHidden = true
                self?.activityIndicator.isHidden = false
            case .paused(play: let play):
                self?.state = .paused
                self?.activityIndicator.isHidden = true
                self?.playButton.isHidden = false
                self?.skipButton.isHidden = true
                self?.playButton.setTitle("▷", for: .normal)
                self?.didTogglePlay = play
            case .playing(track: let track, pause: let pause, skip: let skip):
                self?.state = .playing
                self?.track = track
                self?.activityIndicator.isHidden = true
                self?.playButton.isHidden = false
                self?.skipButton.isHidden = false
                self?.playButton.setTitle("||", for: .normal)
                self?.didTogglePlay = pause
                self?.didSkip = skip
            case .error(let error, retry: let retry):
                self?.state = .paused
                self?.activityIndicator.isHidden = true
                self?.showError(error.localizedDescription, tryAgain: retry)
            }
        }
        .store(in: &cancellables)
    }

    private var didTogglePlay: (() -> Void)?
    private var didSkip: (() -> Void)?

    private var cancellables: Set<AnyCancellable> = []

    private let playlistController = PlaylistController(
        dataStore: UserDefaults.standard
            .dataStore(forKey: "playlistController")
    )

    private func setupViews() {
        errorLabel.isHidden = true
        tryAgainButton.isHidden = true
        tryAgainButton.addTarget(self,
                                 action: #selector(didPressTryAgain),
                                 for: .touchUpInside)
        setButtonsAndMetadataVisibility()
        setInclusionLabelVisibilities(playlistVisibility: .collapsed)
        clearMetadataLabels()
        setupBluetoothLabel()
        setBluetoothLabel()
        tableView.tableFooterView = UIView()
        tableView.register(TableViewCell.self,
                           forCellReuseIdentifier: String(describing: TableViewCell.self))
        #if DEBUG
        addDebugButton()
        #endif
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setPlaylistVisibility(.collapsed)
        animateLayout()
    }

    private func clearMetadataLabels() {
        trackLabel.text = nil
        artistLabel.text = nil
    }

    private func setupBluetoothLabel() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAudioRouteChange),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: nil)
    }

    @objc
    private func handleAudioRouteChange(notification: Notification) {
        DispatchQueue.main.async {
            Log.info(#function)

            self.setBluetoothLabel()

            guard let previousRoute = notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription else {
                return
            }

            if self.state == .playing &&
                previousRoute
                    .outputs
                    .contains(where: self.isBluetooth) {

                self.didTogglePlay?()
            }
        }
    }

    private func isBluetooth(port: AVAudioSessionPortDescription) -> Bool {
        return [AVAudioSession.Port.bluetoothA2DP,
                .bluetoothHFP,
                .bluetoothLE]
            .contains(port.portType)
    }

    private func setBluetoothLabel() {
        let name = AVAudioSession
            .sharedInstance()
            .currentRoute
            .outputs
            .first(where: isBluetooth)?
            .portName

        bluetoothLabel.text = name
    }

    // MARK: - Playback

    @IBAction private func togglePlay() {
        didTogglePlay?()
    }

    private func setButtonsAndMetadataVisibility() {
        let metadataAlpha: CGFloat = state == .playing ? 1 : 0.5
        trackLabel.alpha = metadataAlpha
        artistLabel.alpha = metadataAlpha
        coverImage.alpha = metadataAlpha

        let playlistHandleAlpha: CGFloat = state == .paused || playlistEditorIsNotCollapsed
            ? 1
            : 0.5
        playlistHandle.alpha = playlistHandleAlpha

        removeControlSubscriptions()
        setupControlSubscriptions()
    }

    private var commandCenter: MPRemoteCommandCenter {
        return .shared()
    }
    private var playControlSubscription: Any?
    private var nextControlSubscription: Any?

    private func removeControlSubscriptions() {
        playControlSubscription.map(
            commandCenter.togglePlayPauseCommand.removeTarget
        )
        playControlSubscription = nil

        nextControlSubscription.map(
            commandCenter.nextTrackCommand.removeTarget
        )
        nextControlSubscription = nil
    }

    private func setupControlSubscriptions() {
        guard state != .initial else {
            return
        }
        let togglePlayCommand = state == .paused
            ? commandCenter.playCommand
            : commandCenter.pauseCommand
        playControlSubscription = togglePlayCommand
            .addTarget { [weak self] event in
                Log.info("MPRemote: togglePlayPauseCommand")
                guard let strongSelf = self else {
                    return .commandFailed
                }
                strongSelf.togglePlay()
                return .success
        }
        if state == .playing {
            nextControlSubscription = commandCenter
                .nextTrackCommand
                .addTarget { [weak self] event in
                    Log.info("MPRemote: nextTrackCommand")
                    guard let strongSelf = self else {
                        return .commandFailed
                    }
                    strongSelf.play()
                    return .success
            }
        }
    }

    @IBAction private func play() {
        didSkip?()
    }

    // MARK: - Playlists

    @IBAction private func highlightPlaylistHandle() {
        playlistHandle.backgroundColor = UIColor(white: 0.25, alpha: 1)
        playlistHandle.alpha = 1
    }

    private func unhighlightPlaylistHandle() {
        playlistHandle.backgroundColor = UIColor(white: 0.15, alpha: 1)
    }

    @IBAction private func togglePlaylistVisibility() {
        let newVisibility = playlistEditorIsNotCollapsed
            ? PlaylistVisibility.collapsed
            : .expanded

        unhighlightPlaylistHandle()
        setPlaylistVisibility(newVisibility)
    }

    private var playlistEditorIsNotCollapsed: Bool {
        listHeightConstraint.constant != minimumListHeight
    }

    @IBAction func panList(_ pan: UIPanGestureRecognizer) {
        switch pan.state {
        case .began:
            listPanStartingHeight = listHeightConstraint.constant
        case .changed:
            listHeightConstraint.constant = listPanStartingHeight - pan.translation(in: view).y
            fadeViewsByListHeight()
        case .ended:
            let visibility: PlaylistVisibility
            let velocity = pan.velocity(in: view).y
            if abs(velocity) > 200 {
                visibility = velocity < 0
                    ? .expanded
                    : .collapsed
            } else {
                let currentHeight = listHeightConstraint.constant
                let halfMaximumHeight = (maximumListHeight - minimumListHeight) / 2
                visibility = currentHeight < halfMaximumHeight
                    ? .collapsed
                    : .expanded
            }
            unhighlightPlaylistHandle()
            setPlaylistVisibility(visibility)
        default:
            break
        }
    }

    enum PlaylistVisibility { case collapsed, expanded }

    private func setPlaylistVisibility(_ visibility: PlaylistVisibility) {
        let endHeight = visibility == .collapsed
            ? minimumListHeight
            : maximumListHeight

        listHeightConstraint.constant = endHeight
        setInclusionLabelVisibilities(playlistVisibility: visibility)
        playlistHandle.alpha = visibility == .expanded || state == .paused
            ? 1
            : 0.5
        fadeViewsByListHeight()
        animateLayout()
    }

    private func fadeViewsByListHeight() {
        let span = maximumListHeight - minimumListHeight
        let currentHeightInSpan = listHeightConstraint.constant - minimumListHeight
        let quotient = min(max(0, currentHeightInSpan / span), 1)

        safeAreaBottomCover.alpha = 1 - quotient
        playerContainer.alpha = 1 - quotient / 2
    }

    private func animateLayout() {
        animate { self.view.layoutIfNeeded() }
    }

    private func animate(_ animations: @escaping () -> Void) {
        UIView.animate(withDuration: 0.25,
                       delay: 0,
                       options: .curveEaseOut,
                       animations: animations)
    }

    // MARK: - Error Handling

    @objc private func didPressTryAgain() {
        tryAgain?()
    }

    private var tryAgain: (() -> Void)?

    private func showError(_ message: String, tryAgain: (() -> Void)? = nil) {
        errorLabel.text = message
        self.tryAgain = tryAgain
            .map { tryAgain in
                { [weak self] in
                    self?.hideError()
                    tryAgain()
                }
        }
        animate {
            self.errorLabel.isHidden = false
            self.errorLabel.alpha = 1
            self.tryAgainButton.isHidden = tryAgain == nil
            self.tryAgainButton.alpha = tryAgain == nil ? 0 : 1
        }
    }

    private func hideError() {
        animate {
            self.errorLabel.alpha = 0
            self.errorLabel.isHidden = true
            self.tryAgainButton.alpha = 0
            self.tryAgainButton.isHidden = true
        }
    }
}

extension SpuffleViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlists.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: TableViewCell.self),
                                                 for: indexPath) as! TableViewCell

        configure(cell, for: indexPath)

        return cell
    }

    private func configure(_ cell: TableViewCell, for indexPath: IndexPath) {
        let playlist = playlists[indexPath.row]
        cell.textLabel?.text = playlist.name

        cell.cancellable = playlist.isExcluded.print()
            .sink { [weak cell] isExcluded in
                cell?.textLabel?.font = .systemFont(ofSize: 17, weight: isExcluded ? .regular : .semibold)
                cell?.textLabel?.textAlignment = isExcluded ? .right : .left
            }
    }
}

final class TableViewCell: UITableViewCell {

    var cancellable: AnyCancellable?
}

extension SpuffleViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let playlist = playlists[indexPath.row]

        isLastIncludedPlaylist(playlist)
            .prefix(1)
            .sink { [weak self] isLastIncludedPlaylist in

                isLastIncludedPlaylist
                    ? self?.alertForLastIncludedPlaylist()
                    : playlist.toggleIsExcluded()

                self?.setInclusionLabelVisibilities(playlistVisibility: .expanded,
                                                    animated: true)
            }
            .store(in: &cancellables)
    }

    private func isLastIncludedPlaylist(_ playlist: Playlist) -> AnyPublisher<Bool, Never> {

        let hasOnlyOneIncludedPlaylist = playlistController.includedPlaylists
            .map { $0.count == 1 }

        return playlist.isExcluded
            .combineLatest(hasOnlyOneIncludedPlaylist)
            .map { isExcluded, hasOnlyOneIncludedPlaylist in
                !isExcluded && hasOnlyOneIncludedPlaylist
            }
            .eraseToAnyPublisher()
    }

    private func alertForLastIncludedPlaylist() {
        includeLabel.transform = .init(scaleX: 1.2, y: 1.2)
        UIView.animate(withDuration: 0.25) { [includeLabel] in
            includeLabel?.transform = .identity
        }
    }

    private func setInclusionLabelVisibilities(playlistVisibility: PlaylistVisibility, animated: Bool = false) {
        let isListCollapsed = Just(playlistVisibility == .collapsed)

        let allPlaylistsAreIncluded = playlistController.playlists
            .map { $0.count }
            .combineLatest(playlistController
                            .includedPlaylists
                            .map { $0.count })
            .map { total, included in
                total == included
            }

        let hide = isListCollapsed
            .combineLatest(allPlaylistsAreIncluded)
            .map { $0 || $1 }

        hide
            .prefix(1)
            .sink { [includeLabel, excludeLabel] hide in

                let set = {
                    [includeLabel, excludeLabel].forEach {
                        $0?.alpha = hide ? 0 : 1
                    }
                }

                if animated {
                    UIView.animate(withDuration: 0.25,
                                   delay: 0,
                                   options: [.beginFromCurrentState],
                                   animations: set)
                } else {
                    set()
                }
            }
            .store(in: &cancellables)
    }
}
