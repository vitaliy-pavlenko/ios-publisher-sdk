//
//  CRCacheAdUnit.m
//  pubsdk
//
//  Created by Adwait Kulkarni on 1/7/19.
//  Copyright © 2019 Criteo. All rights reserved.
//

#import "CRCacheAdUnit.h"

@implementation CRCacheAdUnit
{
    NSUInteger _hash;
}

- (instancetype) init {
    CGSize size = CGSizeMake(0.0,0.0);
    return [self initWithAdUnitId:@"" size:size];
}

- (instancetype) initWithAdUnitId:(NSString *)adUnitId
                             size:(CGSize)size {
    if(self = [super init]) {
        _adUnitId = adUnitId;
        _size = size;
        // to get rid of the decimal point
        NSUInteger width = floor(size.width);
        NSUInteger height = floor(size.height);
        _hash = [[NSString stringWithFormat:@"%@_x_%lu_x_%lu", _adUnitId, (unsigned long)width, (unsigned long)height] hash];
    }
    return self;
}

- (instancetype) initWithAdUnitId:(NSString *)adUnitId
                            width:(CGFloat)width
                           height:(CGFloat)height {
    CGSize size = CGSizeMake(width, height);
    return [self initWithAdUnitId:adUnitId size:size];
}

- (NSUInteger) hash {
    return _hash;
}

- (BOOL) isEqual:(id)object {
    if (![object isKindOfClass:[CRCacheAdUnit class]]) {
        return NO;
    }
    CRCacheAdUnit *obj = (CRCacheAdUnit *) object;
    return self.hash == obj.hash;
}

- (instancetype) copyWithZone:(NSZone *)zone {
    CRCacheAdUnit *copy = [[CRCacheAdUnit alloc] initWithAdUnitId:self.adUnitId size:self.size];
    return copy;
}

- (NSString *) cdbSize {
    return [NSString stringWithFormat:@"%lux%lu"
            , (unsigned long)self.size.width
            , (unsigned long)self.size.height];
}
@end
