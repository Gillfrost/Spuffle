//  Copyright (c) 2021 André Gillfrost
//  Licensed under the MIT license

import Foundation

struct SpuffleError: LocalizedError {

    let error: Error
    let retry: () -> Void

    var errorDescription: String { error.localizedDescription }
}
