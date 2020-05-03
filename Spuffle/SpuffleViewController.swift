//  Copyright (c) 2019 André Gillfrost
//  Licensed under the MIT license

import UIKit
import AVFoundation
import MediaPlayer

final class SpuffleViewController: UIViewController {

    private enum State {
        case initial, loaded, playing, paused
    }

    private struct Playlist {
        let uri: URL
        let name: String
        let trackCount: UInt

        private (set) var excluded: Bool

        init(uri: URL, name: String, trackCount: UInt, excluded: Bool) {
            self.uri = uri
            self.name = name
            self.trackCount = trackCount
            self.excluded = excluded
        }

        mutating func toggleExcluded() {
            excluded.toggle()
        }
    }

    private struct Metadata {
        let track: String
        let artist: String
        let duration: TimeInterval
    }

    var session: SPTSession?

    private var controller: SPTAudioStreamingController {
        return .sharedInstance()
    }

    private var state = State.initial {
        didSet {
            setButtonsAndMetadataVisibility()
        }
    }

    private var metadata: Metadata? {
        didSet {
            trackLabel.text = metadata.map { "\"\($0.track)\"" }
            artistLabel.text = metadata.map { $0.artist }
            setNowPlayingInfo()
        }
    }

    private func setNowPlayingInfo() {
        let artworkProperty = artwork.map { image in
            MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }.map { [MPMediaItemPropertyArtwork: $0] }
            ?? [:]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = metadata.map {
            [
                MPMediaItemPropertyTitle: $0.track,
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
            if state == .initial {
                state = .loaded
            }
        }
    }

    private enum StorageKey: String {
        case excludedPlaylistUris
    }

    private var excludedPlaylistUris: Set<String> {
        get {
            return UserDefaults.standard
                .data(forKey: StorageKey.excludedPlaylistUris.rawValue)
                .flatMap {
                    try? JSONDecoder()
                        .decode(Set<String>.self, from: $0)
                }
                ?? []
        }
        set {
            do {
                let data = try JSONEncoder()
                    .encode(newValue)

                UserDefaults.standard
                    .set(data, forKey: StorageKey.excludedPlaylistUris.rawValue)

            } catch {
                Log.error(error)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupAudioController()
    }

    private func setupViews() {
        errorLabel.isHidden = true
        tryAgainButton.isHidden = true
        tryAgainButton.addTarget(self,
                                 action: #selector(didPressTryAgain),
                                 for: .touchUpInside)
        setButtonsAndMetadataVisibility()
        setInclusionLabelVisibilities(playlistVisibility: .collapsed)
        clearMetadataLabels()
        setBluetoothLabel()
        tableView.tableFooterView = UIView()
        #if DEBUG
        addDebugButton()
        #endif
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setPlaylistVisibility(.collapsed)
        animateLayout()
    }

    deinit {
        deactivateAudioSession()
    }

    private func activateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(true, options: [])
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [])
    }

    private func clearMetadataLabels() {
        trackLabel.text = nil
        artistLabel.text = nil
    }

    private func setupAudioController() {
        Log.info(#function)
        controller.delegate = self
        controller.playbackDelegate = self
        do {
            try controller.start(withClientId: AppSecrets.clientId)
            try AVAudioSession.sharedInstance().setCategory(.playback)
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(handleAudioRouteChange),
                                                   name: AVAudioSession.routeChangeNotification,
                                                   object: nil)

            loadPlaylists()
        } catch {
            Log.error(error)
            showError("There was a problem setting up music playback. Please try again.") { [weak self] in
                self?.setupAudioController()
            }
        }
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

                self.pause()
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
        state == .playing ? pause() : play()
    }

    private func setButtonsAndMetadataVisibility() {
        let title = state == .playing ? "||" : "▷"
        playButton.setTitle(title, for: .normal)
        playButton.isHidden = state == .initial

        skipButton.isHidden = state != .playing

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
        playControlSubscription = commandCenter
            .togglePlayPauseCommand
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

    private var playingList: Playlist? = nil

    @IBAction private func play() {
        Log.info(#function)
        guard let playlist = randomPlaylist() else {
            Log.error("Play called without playlists")
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
            Log.error("Play called when state was .initial")
        case .playing, .loaded:
            Log.info("Play Spotify URI")
            controller.playSpotifyURI(playlist.uri.absoluteString,
                                      startingWith: UInt.random(in: 0..<playlist.trackCount),
                                      startingWithPosition: 0) { $0.map { Log.error($0) }}
        case .paused:
            controller.setIsPlaying(true) { $0.map { Log.error($0) }}
        }
    }

    private func randomPlaylist() -> Playlist? {
        let includedPlaylists = playlists.filter { !$0.excluded }

        guard !includedPlaylists.isEmpty else {
            return nil
        }

        func playlist(containing trackIndex: UInt, playlistIndex: Int = 0) -> Playlist {
            let list = includedPlaylists[playlistIndex]

            return trackIndex <= list.trackCount
                ? list
                : playlist(containing: trackIndex - list.trackCount,
                           playlistIndex: playlistIndex + 1)
        }

        let includedTrackCount = includedPlaylists
            .map { $0.trackCount }
            .reduce(0, +)

        let randomTrackIndex = UInt.random(in: 0...includedTrackCount)

        return playlist(containing: randomTrackIndex)
    }

    private func login() {
        guard let token = session?.accessToken else {
            Log.error("Login called without session")
            return
        }
        controller.login(withAccessToken: token)
    }

    private func pause() {
        Log.info(#function)
        controller.setIsPlaying(false) { $0.map { Log.error($0) }}
        state = .paused
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
        playerContainer.alpha = 1 - quotient
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

    private func loadPlaylists() {
        guard let token = session?.accessToken else {
            Log.error("Load playlists called without token")
            return
        }
        getPlaylists(token: token) { [weak self] result in
            switch result {
            case .success(let playlists):
                self?.playlists = playlists
                self?.tableView.reloadData()
            case .failure(let error):
                Log.error(error)
                self?.showError("There was a problem loading your playlists. Please try again.") {
                    self?.loadPlaylists()
                }
            }
        }
    }

    private func getPlaylists(token: String, completion: @escaping (Result<[Playlist], Error>) -> Void) {
        SPTUser.requestCurrentUser(withAccessToken: token) { [weak self] error, result in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let user = result as? SPTUser else {
                assertionFailure()
                return
            }
            self?.getPlaylists(user: user.canonicalUserName, token: token, completion: completion)
        }
    }

    private func getPlaylists(user: String,
                              token: String,
                              completion: @escaping (Result<[Playlist], Error>) -> Void) {

        SPTPlaylistList.playlists(forUser: user,
                                  withAccessToken: token) { [weak self] (error, result) in
                                    self?.playlistCallback(error: error, result: result, token: token, completion: completion)
        }
    }

    private func playlistCallback(error: Error?,
                                  result: Any?,
                                  token: String,
                                  completion: @escaping (Result<[Playlist], Error>) -> Void) {
        if let error = error {
            completion(.failure(error))
            return
        }
        guard let result = result else {
            Log.error("Nil result in playlist callback")
            assertionFailure()
            return
        }
        guard let listPage = result as? SPTListPage else {
            Log.error("Playlist callback result is not SPTListPage")
            assertionFailure()
            return
        }

        let excludedPlaylistUris = self.excludedPlaylistUris

        let playlists = listPage.tracksForPlayback()?
            .compactMap { $0 as? SPTPartialPlaylist }
            .map {
                Playlist(uri: $0.playableUri,
                         name: $0.name,
                         trackCount: $0.trackCount,
                         excluded: excludedPlaylistUris.contains($0.playableUri.absoluteString))

            } ?? []

        if listPage.hasNextPage {
            listPage.requestNextPage(withAccessToken: token) { [weak self] in
                self?.playlistCallback(error: $0,
                                       result: $1,
                                       token: token,
                                       completion: {
                                        guard case .success(let morePlaylists) = $0 else {
                                            completion($0)
                                            return
                                        }
                                        completion(.success(playlists + morePlaylists))
                })
            }
        } else {
            completion(.success(playlists))
        }
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

        guard !isLastIncludedPlaylist(indexPath) else {
            alertForLastIncludedPlaylist()
            return
        }

        playlists[indexPath.row].toggleExcluded()
        let playlist = playlists[indexPath.row]
        if playlist.excluded {
            excludedPlaylistUris.insert(playlist.uri.absoluteString)
        } else {
            excludedPlaylistUris.remove(playlist.uri.absoluteString)
        }

        tableView.cellForRow(at: indexPath).map {
            configure($0, for: indexPath)
        }

        setInclusionLabelVisibilities(playlistVisibility: .expanded, animated: true)
    }

    private func isLastIncludedPlaylist(_ indexPath: IndexPath) -> Bool {
        return !playlists[indexPath.row].excluded
            && playlists.filter { !$0.excluded }.count == 1
    }

    private func alertForLastIncludedPlaylist() {
        includeLabel.transform = .init(scaleX: 1.2, y: 1.2)
        UIView.animate(withDuration: 0.25) { [includeLabel] in
            includeLabel?.transform = .identity
        }
    }

    private func setInclusionLabelVisibilities(playlistVisibility: PlaylistVisibility, animated: Bool = false) {
        let isListCollapsed = playlistVisibility == .collapsed
        let allPlaylistsAreIncluded = playlists.map { $0.excluded }.allSatisfy(!)

        let hide = isListCollapsed
            || allPlaylistsAreIncluded

        let set = { [includeLabel, excludeLabel] in
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
}

extension SpuffleViewController: SPTAudioStreamingDelegate {

    func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController) {
        activateAudioSession()
        if state == .playing {
            play()
        }
    }

    func audioStreamingDidLogout(_ audioStreaming: SPTAudioStreamingController) {
        Log.info(#function)
    }

    func audioStreamingDidDisconnect(_ audioStreaming: SPTAudioStreamingController) {
        Log.info(#function)
    }

    func audioStreamingDidReconnect(_ audioStreaming: SPTAudioStreamingController) {
        Log.info(#function)
    }

    func audioStreamingDidLosePermission(forPlayback audioStreaming: SPTAudioStreamingController) {
        Log.info(#function)
    }

    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didReceiveError error: Error) {
        Log.error(error)
    }

    func audioStreamingDidEncounterTemporaryConnectionError(_ audioStreaming: SPTAudioStreamingController) {
        Log.info(#function)
    }
}

extension SpuffleViewController: SPTAudioStreamingPlaybackDelegate {

    func audioStreaming(_ audioStreaming: SPTAudioStreamingController, didChange metadata: SPTPlaybackMetadata) {
        self.metadata = metadata.currentTrack
            .map { ($0.name, $0.artistName, $0.duration) }
            .map(Metadata.init)

        artworkUrl = metadata.currentTrack?
            .albumCoverArtURL
            .flatMap(URL.init)
    }
}
