//  Copyright (c) 2019 André Gillfrost
//  Licensed under the MIT license

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        #if DEBUG
        Log.errorAction = Alert.show
        #endif

        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {

        guard let signInViewController = (window?.rootViewController as? SignInViewController) else {
            assertionFailure()
            return false
        }
        signInViewController.showLoadingIndicator()

        return signInViewController.sessionManager.application(app, open: url, options: options)
    }
}
