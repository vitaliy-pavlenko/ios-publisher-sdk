//
//  CR_DeviceInfo.h
//  pubsdk
//
//  Created by Paul Davis on 1/28/19.
//  Copyright © 2019 Criteo. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CR_DeviceInfo : NSObject

@property (nonatomic, readonly) NSString *userAgent;
@property (nonatomic, readonly) NSString *deviceId;

@end

NS_ASSUME_NONNULL_END