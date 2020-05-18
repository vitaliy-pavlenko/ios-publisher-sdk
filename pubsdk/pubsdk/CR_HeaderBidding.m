//
//  CR_HeaderBidding.m
//  pubsdk
//
//  Copyright © 2018-2020 Criteo. All rights reserved.
//


#import "CR_HeaderBidding.h"
#import "CR_TargetingKeys.h"
#import "CR_CdbBid.h"
#import "CR_CacheAdUnit.h"
#import "CR_NativeAssets.h"
#import "CR_NativeProduct.h"
#import "CRAdUnit+Internal.h"
#import "CR_BidManagerHelper.h"
#import "NSString+CR_Url.h"

@implementation CR_HeaderBidding

- (void)enrichRequest:(id)adRequest
              withBid:(CR_CdbBid *)bid
               adUnit:(CR_CacheAdUnit *)adUnit {
    if([self isDfpRequest:adRequest]) {
        [self addCriteoBidToDfpRequest:adRequest
                               withBid:bid
                                adUnit:adUnit];
    } else if ([self isMoPubRequest:adRequest]) {
        [self addCriteoBidToMopubRequest:adRequest
                                 withBid:bid];
    } else if ([adRequest isKindOfClass:NSMutableDictionary.class]) {
        [self addCriteoBidToDictionary:adRequest
                               withBid:bid];
    }
}

- (void)removeCriteoBidsFromMoPubRequest:(id)adRequest {
    NSAssert([self isMoPubRequest:adRequest],
             @"Given object isn't from MoPub API: %@",
             adRequest);
    // For now, this method is a class method because it is used
    // in NSObject+Criteo load for swizzling. 
    [CR_BidManagerHelper removeCriteoBidsFromMoPubRequest:adRequest];
}

- (BOOL)isMoPubRequest:(id)request {
    NSString *className = NSStringFromClass([request class]);
    BOOL result =
    [className isEqualToString:@"MPAdView"] ||
    [className isEqualToString:@"MPInterstitialAdController"];
    return result;
}


#pragma mark - Private

- (BOOL)isDfpRequest:(id)request {
    NSString *name = NSStringFromClass([request class]);
    BOOL result =
    [name isEqualToString:@"DFPRequest"] ||
    [name isEqualToString:@"DFPNRequest"] ||
    [name isEqualToString:@"DFPORequest"] ||
    [name isEqualToString:@"GADRequest"] ||
    [name isEqualToString:@"GADORequest"] ||
    [name isEqualToString:@"GADNRequest"];
    return result;
}

- (void)addCriteoBidToDictionary:(NSMutableDictionary*)dictionary
                         withBid:(CR_CdbBid *)bid {
    dictionary[CR_TargetingKey_crtDisplayUrl] = bid.displayUrl;
    dictionary[CR_TargetingKey_crtCpm] = bid.cpm;
}

- (void) addCriteoBidToDfpRequest:(id) adRequest
                           withBid:(CR_CdbBid *)bid
                           adUnit:(CR_CacheAdUnit *)adUnit {
    SEL dfpCustomTargeting = NSSelectorFromString(@"customTargeting");
    SEL dfpSetCustomTargeting = NSSelectorFromString(@"setCustomTargeting:");
    if([adRequest respondsToSelector:dfpCustomTargeting] && [adRequest respondsToSelector:dfpSetCustomTargeting]) {

// this is for ignoring warning related to performSelector: on unknown selectors
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id targeting = [adRequest performSelector:dfpCustomTargeting];

        if (targeting == nil) {
            targeting = [NSDictionary dictionary];
        }

        if ([targeting isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary* customTargeting = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *) targeting];
            customTargeting[CR_TargetingKey_crtCpm] = bid.cpm;
            if(adUnit.adUnitType == CRAdUnitTypeNative) {
                // bid will contain atleast one product, a privacy section and atleast one impression pixel
                CR_NativeAssets *nativeAssets = bid.nativeAssets;
                if(nativeAssets.products.count > 0) {
                    CR_NativeProduct *product = nativeAssets.products[0];
                    [self setDfpValue:product.title forKey:CR_TargetingKey_crtnTitle inDictionary:customTargeting];
                    [self setDfpValue:product.description forKey:CR_TargetingKey_crtnDesc inDictionary:customTargeting];
                    [self setDfpValue:product.price forKey:CR_TargetingKey_crtnPrice inDictionary:customTargeting];
                    [self setDfpValue:product.clickUrl forKey:CR_TargetingKey_crtnClickUrl inDictionary:customTargeting];
                    [self setDfpValue:product.callToAction forKey:CR_TargetingKey_crtnCta inDictionary:customTargeting];
                    [self setDfpValue:product.image.url forKey:CR_TargetingKey_crtnImageUrl inDictionary:customTargeting];
                }
                CR_NativeAdvertiser *advertiser = nativeAssets.advertiser;
                [self setDfpValue:advertiser.description forKey:CR_TargetingKey_crtnAdvName inDictionary:customTargeting];
                [self setDfpValue:advertiser.domain forKey:CR_TargetingKey_crtnAdvDomain inDictionary:customTargeting];
                [self setDfpValue:advertiser.logoImage.url forKey:CR_TargetingKey_crtnAdvLogoUrl inDictionary:customTargeting];
                [self setDfpValue:advertiser.logoClickUrl forKey:CR_TargetingKey_crtnAdvUrl inDictionary:customTargeting];

                CR_NativePrivacy *privacy = nativeAssets.privacy;
                [self setDfpValue:privacy.optoutClickUrl forKey:CR_TargetingKey_crtnPrUrl inDictionary:customTargeting];
                [self setDfpValue:privacy.optoutImageUrl forKey:CR_TargetingKey_crtnPrImageUrl inDictionary:customTargeting];
                [self setDfpValue:privacy.longLegalText forKey:CR_TargetingKey_crtnPrText inDictionary:customTargeting];
                customTargeting[CR_TargetingKey_crtnPixCount] =
                    [NSString stringWithFormat:@"%lu", (unsigned long) nativeAssets.impressionPixels.count];
                for(int i = 0; i < bid.nativeAssets.impressionPixels.count; i++) {
                    [self setDfpValue:bid.nativeAssets.impressionPixels[i]
                               forKey:[NSString stringWithFormat:@"%@%d", CR_TargetingKey_crtnPixUrl, i]
                         inDictionary:customTargeting];
                }
            }
            else {
                customTargeting[CR_TargetingKey_crtDfpDisplayUrl] = bid.dfpCompatibleDisplayUrl;
            }
            NSDictionary *updatedDictionary = [NSDictionary dictionaryWithDictionary:customTargeting];
            [adRequest performSelector:dfpSetCustomTargeting withObject:updatedDictionary];
#pragma clang diagnostic pop
        }
    }
}

- (void)addCriteoBidToMopubRequest:(id) adRequest
                           withBid:(CR_CdbBid *)bid {
    [self removeCriteoBidsFromMoPubRequest:adRequest];
    SEL mopubKeywords = NSSelectorFromString(@"keywords");
    if([adRequest respondsToSelector:mopubKeywords]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id targeting = [adRequest performSelector:mopubKeywords];

        if (targeting == nil) {
            targeting = @"";
        }

        if ([targeting isKindOfClass:[NSString class]]) {
            NSMutableString *keywords = [[NSMutableString alloc] initWithString:targeting];
            if ([keywords length] > 0) {
                [keywords appendString:@","];
            }
            [keywords appendString:CR_TargetingKey_crtCpm];
            [keywords appendString:@":"];
            [keywords appendString:bid.cpm];
            [keywords appendString:@","];
            [keywords appendString:CR_TargetingKey_crtDisplayUrl];
            [keywords appendString:@":"];
            [keywords appendString:bid.mopubCompatibleDisplayUrl];
            [adRequest setValue:keywords forKey:@"keywords"];
#pragma clang diagnostic pop
        }
    }
}

- (void)setDfpValue:(NSString *)value
             forKey:(NSString *)key
       inDictionary:(NSMutableDictionary*)dict {
    if(value.length > 0) {
        dict[key] = [NSString dfpCompatibleString:value];
    }
}

@end