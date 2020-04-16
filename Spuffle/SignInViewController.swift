//  Copyright (c) 2019 André Gillfrost
//  Licensed under the MIT license

import UIKit
import SafariServices

final class SignInViewController: UIViewController {

    @IBOutlet private weak var contentView: UIView!

    private var auth: SPTAuth { return SPTAuth.defaultInstance() }

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
        let isSessionValid = auth.session?.isValid() == true
        if isSessionValid {
            Log.info("Session is valid")
            removeAuthenticationStatusObservers()
            showSpuffle()
        } else {
            Log.info("No valid session")
            dismissSpuffle()
            showContent()
        }
    }

    @IBAction private func signIn() {
        hideContentAnimated()
        removeAuthenticationStatusObservers()
        addAuthenticationStatusObservers()

        SPTAuth.supportsApplicationAuthentication()
            ? performAppAuthentication()
            : performWebAuthentication()
    }

    private func performAppAuthentication() {
        Log.info("Starting app authentication")
        let url = auth.spotifyAppAuthenticationURL()

        UIApplication.shared.open(url)
    }

    private func performWebAuthentication() {
        Log.info("Starting web authentication")
        let url = SPTAuth.defaultInstance().spotifyWebAuthenticationURL()
        let webController = SFSafariViewController(url: url)

        present(webController, animated: true)
    }

    private func addAuthenticationStatusObservers() {
        notificationCenter
            .addObserver(self,
                         selector: #selector(checkSession),
                         name: .sessionAcquired,
                         object: nil)
        notificationCenter
            .addObserver(self,
                         selector: #selector(showAuthenticationFailureAlert),
                         name: .authenticationFailed,
                         object: nil)
        notificationCenter
            .addObserver(self,
                         selector: #selector(checkSession),
                         name: UIApplication.didBecomeActiveNotification,
                         object: nil)
    }

    private var notificationCenter: NotificationCenter { .default }

    private func removeAuthenticationStatusObservers() {
        notificationCenter
            .removeObserver(self,
                            name: .sessionAcquired,
                            object: nil)
        notificationCenter
            .removeObserver(self,
                            name: .authenticationFailed,
                            object: nil)
        notificationCenter
            .removeObserver(self,
                            name: UIApplication.didBecomeActiveNotification,
                            object: nil)
    }

    @objc private func showAuthenticationFailureAlert() {
        Alert.show("There was a problem authenticating your Spotify account. Please try again")
        checkSession()
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
        if presentedViewController is SFSafariViewController {
            dismiss(animated: true)
            return
        }
        guard presentedViewController == nil else {
            Log.error("Sign-in tried to perform segue with controller \(String(describing: presentedViewController)) already presented")
            return
        }
        performSegue(withIdentifier: "spuffle", sender: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let spuffleController = segue.destination as? SpuffleViewController else {
            Log.error("Unexpected segue \(segue) from sign-in controller")
            return
        }
        spuffleController.session = auth.session
    }

    private func dismissSpuffle() {
        guard presentedViewController != nil else {
            return
        }
        dismiss(animated: true)
    }
}
