/*
 Copyright 2017 Spotify AB

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import <Foundation/Foundation.h>
#import "SPTDiskCaching.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The `SPTDiskCache` class implements the `SPTDiskCaching` protocol and provides a caching mechanism based on memory mapped files.
 */
@interface SPTDiskCache : NSObject <SPTDiskCaching>

/**
 * @brief Initialize the disk cache with capacity.
 * @param capacity The maximum capacity of the disk cache, in bytes.
 */
- (instancetype)initWithCapacity:(NSUInteger)capacity NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) NSUInteger capacity;

@end

NS_ASSUME_NONNULL_END
