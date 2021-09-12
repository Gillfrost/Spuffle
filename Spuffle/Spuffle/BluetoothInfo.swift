//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import AVFoundation
import Combine

final class BluetoothInfo: ObservableObject {

    @Published private (set) var bluetoothName: String?
    @Published private (set) var didChangeFromBluetooth = false

    init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(audioRouteDidChange),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: nil)
    }

    @objc
    private func audioRouteDidChange(notification: Notification) {
        DispatchQueue.main.async {
            Log.info(#function)

            self.setBluetoothName()

            guard let previousRoute = notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription else {
                return
            }

            self.didChangeFromBluetooth = previousRoute
                .outputs
                .contains(where: self.isBluetooth)
        }
    }

    private func setBluetoothName() {
        bluetoothName = AVAudioSession
            .sharedInstance()
            .currentRoute
            .outputs
            .first(where: isBluetooth)?
            .portName
    }

    private func isBluetooth(port: AVAudioSessionPortDescription) -> Bool {
        return [AVAudioSession.Port.bluetoothA2DP,
                .bluetoothHFP,
                .bluetoothLE]
            .contains(port.portType)
    }
}
