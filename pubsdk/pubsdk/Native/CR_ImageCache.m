//
//  CR_ImageCache.m
//  CriteoPublisherSdk
//
//  Copyright © 2018-2020 Criteo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CR_ImageCache.h"

@interface CR_ImageRef : NSObject

@property(strong, nonatomic, readonly) UIImage *image;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithImage:(UIImage *)image NS_DESIGNATED_INITIALIZER;

@end

@implementation CR_ImageRef

- (instancetype)initWithImage:(UIImage *)image {
    if (self = [super init]) {
        _image = image;
    }
    return self;
}

@end

@interface CR_ImageCache ()

/**
 * Same images may appear several times for a same ad unit, or even on all ad unit (AdChoice icon).
 * To improve the UX and reduce the network and infra cost, a LRU or LFU cache should be internally used to store
 * references to downloaded images given their URI.
 *
 * It is not documented, but tests show that NSCache follow LRU order when evicting data, if data is not hold.
 * Here we're using an intermediate CR_ImageRef class, so nobody is holding the data except the cache.
 */
@property(strong, nonatomic, readonly) NSCache<NSURL *, CR_ImageRef *> *cache;

@end

@implementation CR_ImageCache

- (instancetype)initWithSizeLimit:(NSUInteger)dataSizeLimit {
    if (self = [super init]) {
        _cache = [[NSCache alloc] init];
        _cache.totalCostLimit = dataSizeLimit;
    }
    return self;
}

- (void)setImage:(UIImage *)image forUrl:(NSURL *)url imageSize:(NSUInteger)size {
    CR_ImageRef *imageRef = [[CR_ImageRef alloc] initWithImage:image];
    [_cache setObject:imageRef forKey:url cost:size];
}

- (nullable UIImage *)imageForUrl:(NSURL *)url {
    CR_ImageRef *imageRef = [_cache objectForKey:url];
    return imageRef.image;
}

@end