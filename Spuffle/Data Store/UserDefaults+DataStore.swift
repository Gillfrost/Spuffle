//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import Foundation

extension UserDefaults {

    func dataStore(forKey key: String) -> DataStore {
        Store(get: { self.data(forKey: key) },
              set: { self.setValue($0, forKey: key) })
    }
}

private struct Store: DataStore {

    let get: () -> Data?
    let set: (Data) -> Void

    func getData() -> Data? {
        get()
    }

    func setData(_ data: Data) {
        set(data)
    }
}
