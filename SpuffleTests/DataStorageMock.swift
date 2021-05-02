//
//  DataStorageMock.swift
//  SpuffleTests
//
//  Created by André on 2021-05-02.
//

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
