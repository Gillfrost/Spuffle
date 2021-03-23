//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import Combine

protocol Player {

    var state: AnyPublisher<PlayerState, Never> { get }
}
