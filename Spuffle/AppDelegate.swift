//  Copyright (c) 2019 André Gillfrost
//  Licensed under the MIT license

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    private var auth: SPTAuth {
        return SPTAuth.defaultInstance()
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        #if DEBUG
        Log.errorAction = Alert.show
        #endif

        auth.clientID = AppSecrets.clientId
        auth.requestedScopes = [SPTAuthPlaylistReadPrivateScope]
        auth.redirectURL = URL(string: "spuffle://spotify-login-callback")
        auth.sessionUserDefaultsKey = "spotify-session"

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {

        guard auth.canHandle(url) else {
            Log.error("Could not open unexpected url \(url)")
            return false
        }
        auth.handleAuthCallback(withTriggeredAuthURL: url) { error, session in
            if let error = error {
                error.localizedDescription == "user_canceled"
                    ? Log.info("User canceled")
                    : Log.error(error.localizedDescription)
                NotificationCenter.default.post(name: .authenticationFailed, object: nil)
                return
            }
            SPTAuth.defaultInstance().session = session
            NotificationCenter.default.post(name: .sessionAcquired, object: nil)
        }
        return true
    }
}

extension Notification.Name {
    static let sessionAcquired = Self("sessionAcquired")
    static let authenticationFailed = Self(rawValue: "authenticationFailed")
}
