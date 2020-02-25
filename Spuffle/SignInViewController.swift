//  Copyright (c) 2019 André Gillfrost
//  Licensed under the MIT license

import UIKit

final class SignInViewController: UIViewController {

    @IBOutlet private weak var signInButton: UIView!

    private var auth: SPTAuth { return SPTAuth.defaultInstance() }

    override func viewDidLoad() {
        super.viewDidLoad()
        hideSignInButton()
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

    @objc private func checkSession() {
        let isSessionValid = auth.session?.isValid() == true
        if isSessionValid {
            Log.info("Session is valid")
            NotificationCenter.default.removeObserver(self,
                                                      name: .sessionAcquired,
                                                      object: nil)
            showSpuffle()
        } else {
            Log.info("No valid session")
            dismissSpuffle()
            showSignInButton()
        }
    }

    @IBAction private func signIn() {
        guard SPTAuth.supportsApplicationAuthentication() else {
            Log.info("Flip-flop authentication not supported")
            // TODO: Handle
            return
        }
        hideSignInButton()
        let url = auth.spotifyAppAuthenticationURL()
        UIApplication.shared.open(url)
        NotificationCenter.default.addObserver(self, selector: #selector(checkSession),
                                               name: .sessionAcquired,
                                               object: nil)
    }

    private func showSpuffle() {
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
