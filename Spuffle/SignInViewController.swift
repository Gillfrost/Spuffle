//  Copyright (c) 2019 André Gillfrost
//  Licensed under the MIT license

import UIKit

final class SignInViewController: UIViewController {

    @IBOutlet private weak var signInButton: UIView!

    private var auth: SPTAuth { return SPTAuth.defaultInstance() }

    override func viewDidLoad() {
        super.viewDidLoad()
        hideSignInButton()
        checkSessionWhenResumingApp()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkSession()
    }

    private func showSignInButton() {
        signInButton.isHidden = false
    }

    private func hideSignInButton() {
        signInButton.isHidden = true
    }

    private func checkSessionWhenResumingApp() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(checkSession),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }

    @objc private func checkSession() {
        let isSessionValid = auth.session?.isValid() == true

        if isSessionValid {
            NotificationCenter.default.removeObserver(self, name: .sessionAcquired, object: nil)
            showSpuffle()
        } else {
            dismissSpuffle()
            showSignInButton()
        }
    }

    @IBAction private func signIn() {
        guard SPTAuth.supportsApplicationAuthentication() else {
            // TODO: Handle
            assertionFailure()
            return
        }
        hideSignInButton()
        let url = auth.spotifyAppAuthenticationURL()
        UIApplication.shared.open(url)
        NotificationCenter.default.addObserver(self, selector: #selector(checkSession), name: .sessionAcquired, object: nil)
    }

    private func showSpuffle() {
        guard presentedViewController == nil else {
            return
        }
        performSegue(withIdentifier: "spuffle", sender: nil)
    }

    private func dismissSpuffle() {
        guard presentedViewController != nil else {
            return
        }
        dismiss(animated: true)
    }
}
