//  Copyright (c) 2019 André Gillfrost
//  Licensed under the MIT license

import UIKit
import SafariServices

final class SignInViewController: UIViewController {

    @IBOutlet private weak var contentView: UIView!

    private let configuration: SPTConfiguration = {
        let configuration = SPTConfiguration(clientID: AppSecrets.clientId,
                                             redirectURL: URL(string: "spuffle://spotify-login-callback")!)
        configuration.tokenSwapURL = URL(string: "https://spuffle.herokuapp.com/swap")
        configuration.tokenRefreshURL = URL(string: "https://spuffle.herokuapp.com/refresh")
        return configuration
    }()

    private (set) lazy var sessionManager = SPTSessionManager(configuration: configuration,
                                                              delegate: self)

    override func viewDidLoad() {
        super.viewDidLoad()
        hideContent()

        #if DEBUG
        addDebugButton()
        #endif
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkSession()
    }

    func showLoadingIndicator() {
        hideContent()
    }

    private func showContent() {
        contentView.alpha = 1
    }

    private func hideContent() {
        contentView.alpha = 0
    }

    private func hideContentAnimated() {
        UIView.animate(withDuration: 0.25,
                       delay: 0,
                       options: [.beginFromCurrentState],
                       animations: hideContent)
    }

    @objc private func checkSession() {
        if sessionManager.session != nil {
            Log.info("Session is valid")
            hideContentAnimated()
            showSpuffle()
        } else {
            Log.info("No valid session")
            dismissSpuffle()
            showContent()
        }
    }

    @IBAction private func signIn() {
        sessionManager.isSpotifyAppInstalled
            ? Log.info("Sign in with app")
            : Log.info("Sign in with credentials")

        sessionManager
            .initiateSession(with: [.playlistReadPrivate,
                                    .streaming],
                             options: .default)
    }

    @IBAction private func showPrivacyPolicy() {
        let url = URL(string: "https://gillfrost.github.io/Spuffle/privacy.html")!
        let webController = SFSafariViewController(url: url)

        hideContentAnimated()

        present(webController,
                animated: true,
                completion: showContent)
    }

    private func showSpuffle() {
        guard presentedViewController == nil else {
            Log.info("Sign-in tried to perform segue with controller \(String(describing: presentedViewController)) already presented")
            retry { [weak self] in self?.showSpuffle() }
            return
        }
        performSegue(withIdentifier: "spuffle", sender: nil)
    }

    private func retry(_ block: @escaping () -> Void) {
        Timer.scheduledTimer(withTimeInterval: 0.25,
                             repeats: false,
                             block:  { _ in
                                block()
        })
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let spuffleController = segue.destination as? SpuffleViewController else {
            Log.error("Unexpected segue \(segue) from sign-in controller")
            return
        }
        spuffleController.session = sessionManager.session
    }

    private func dismissSpuffle() {
        guard presentedViewController != nil else {
            return
        }
        dismiss(animated: true)
    }
}

extension SignInViewController: SPTSessionManagerDelegate {

    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        Log.info(#function)
        DispatchQueue.main.async(execute: checkSession)
    }

    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        Log.error(error)
        Alert.show("There was a problem authenticating your Spotify account. Please try again")
        checkSession()
    }

    func sessionManager(manager: SPTSessionManager, didRenew session: SPTSession) {
        Log.info(#function)
        (presentedViewController as? SpuffleViewController)?.session = session
    }

    func sessionManager(manager: SPTSessionManager, shouldRequestAccessTokenWith code: String) -> Bool {
        hideContentAnimated()
        return true
    }
}
