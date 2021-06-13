//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import Foundation
import Combine

struct Playlist {

    let uri: URL
    let name: String
    let trackCount: UInt
    let isExcluded: AnyPublisher<Bool, Never>
    let toggleIsExcluded: () -> Void
}
