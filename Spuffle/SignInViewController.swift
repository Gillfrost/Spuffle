//  Copyright (c) 2019 André Gillfrost
//  Licensed under the MIT license

import UIKit

final class SignInViewController: UIViewController {

    @IBOutlet private weak var signInButton: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        signInButton.isHidden = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let isSessionValid = SPTAuth.defaultInstance().session?.isValid() == true

        if isSessionValid {
            performSegue(withIdentifier: "spuffle", sender: nil)
        } else {
            signInButton.isHidden = false
        }
    }

    @IBAction private func signIn() {
        print(#function)
    }
}
