//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

protocol DataStore {

    func getData() -> Data?
    func setData(_ data: Data)
}
