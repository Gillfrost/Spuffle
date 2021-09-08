//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

@testable import Spuffle

class MockDataStore: DataStore {

    var data: Data?

    func getData() -> Data? {
        data
    }

    func setData(_ data: Data) {
        self.data = data
    }
}
