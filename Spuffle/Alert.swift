//  Copyright (c) 2019 André Gillfrost
//  Licensed under the MIT license

import UIKit

enum Alert {

    static func show(_ message: String) {
        var window: UIWindow? = UIWindow()
        window?.windowLevel = .alert

        let releaseWindow = { window = nil }

        let presenter = UIViewController()

        let alert = UIAlertController(title: nil,
                                      message: message,
                                      preferredStyle: .alert)

        alert.addAction(.init(title: "Ok",
                              style: .cancel,
                              handler: { _ in releaseWindow() }))


        window?.rootViewController = presenter
        window?.makeKeyAndVisible()

        presenter.present(alert, animated: true)
    }
}
