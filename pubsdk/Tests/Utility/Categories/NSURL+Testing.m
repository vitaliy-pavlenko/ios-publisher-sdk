//
//  NSURL+Testing.m
//  CriteoPublisherSdk
//
//  Copyright © 2018-2020 Criteo. All rights reserved.
//

#import "NSURL+Testing.h"

#import "CR_Config.h"
#import "CR_NativeAssets+Testing.h"

@implementation NSURL (Testing)

- (BOOL)testing_isFeedbackMessageUrlWithConfig:(CR_Config *)config {
    return  [self.absoluteString containsString:config.cdbUrl] &&
            [self.absoluteString containsString:config.csmPath];
}

- (BOOL)testing_isBidUrlWithConfig:(CR_Config *)config {
    return  [self.absoluteString containsString:config.cdbUrl] &&
            [self.absoluteString containsString:config.path];
}

- (BOOL)testing_isAppEventUrlWithConfig:(CR_Config *)config {
    return [self.absoluteString containsString:config.appEventsUrl];
}

- (BOOL)testing_isAppLaunchEventUrlWithConfig:(CR_Config *)config {
    return  [self testing_isAppEventUrlWithConfig:config] &&
            [self.absoluteString containsString:@"eventType=Launch"];
}

- (BOOL)testing_isConfigEventUrlWithConfig:(CR_Config *)config {
    return [self.absoluteString containsString:config.configUrl];
}

- (BOOL)testing_isNativeProductImage {
    return [self.absoluteString isEqualToString:CR_NativeAssets.nativeAssetsFromCdb.products[0].image.url];
}

- (BOOL)testing_isNativeAdvertiserLogoImage {
    return [self.absoluteString isEqualToString:CR_NativeAssets.nativeAssetsFromCdb.advertiser.logoImage.url];
}

- (BOOL)testing_isNativeAdChoiceImage {
    return [self.absoluteString isEqualToString:CR_NativeAssets.nativeAssetsFromCdb.privacy.optoutImageUrl];
}

@end
