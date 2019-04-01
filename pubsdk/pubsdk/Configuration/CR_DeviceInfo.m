//
//  CR_DeviceInfo.m
//  pubsdk
//
//  Created by Paul Davis on 1/28/19.
//  Copyright © 2019 Criteo. All rights reserved.
//

#import <WebKit/WebKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import "CR_DeviceInfo.h"

@implementation CR_DeviceInfo
{
    NSString *_deviceId;
    BOOL _isLoadingUserAgent;
    NSMutableSet *_loadUserAgentCompletionBlocks;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _loadUserAgentCompletionBlocks = [NSMutableSet new];
        _isLoadingUserAgent = NO;
        [self setupUserAgent];
    }
    return self;
}

- (void)waitForUserAgent:(void (^ _Nullable)(void))completion {
    if(self.userAgent) {
        completion();
        return;
    }
    if(completion) {
        @synchronized (_loadUserAgentCompletionBlocks) {
            [_loadUserAgentCompletionBlocks addObject:completion];
        }
    }
}

- (void)setupUserAgent {
    if(_isLoadingUserAgent) {
        return;
    }
    _isLoadingUserAgent = YES;
    // Make sure we're on the main thread because we're calling WKWebView which isn't thread safe
    dispatch_async(dispatch_get_main_queue(), ^{
        WKWebView __block *webView = [[WKWebView alloc] initWithFrame:CGRectZero];
        [webView evaluateJavaScript:@"navigator.userAgent" completionHandler:^(id _Nullable navigatorUserAgent, NSError * _Nullable error) {
            
            // Make sure we're on the main thread because we could call UIWebView which isn't thread safe
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!error && [navigatorUserAgent isKindOfClass:NSString.class]) {
                    self.userAgent = navigatorUserAgent;
                } else {
                    // TODO: Client-side metrics for empty UA
                    self.userAgent = [self userAgentFromUIWebView];
                }
                
                @synchronized (self->_loadUserAgentCompletionBlocks) {
                    for (void (^ completionBlock)(void) in self->_loadUserAgentCompletionBlocks) {
                        completionBlock();
                    }
                    [self->_loadUserAgentCompletionBlocks removeAllObjects];
                }
                self->_isLoadingUserAgent = NO;
            });
        }];
    });
}

- (NSString*)userAgentFromUIWebView {
    // UIWebView is deprecated so we ensure it exists.
    // If not, well nevemind.
    Class uiWebviewClass = NSClassFromString(@"UIWebView");
    if (uiWebviewClass) {
        return [(UIWebView *)[[uiWebviewClass alloc] init] stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
        // TODO: Client-side metrics for still empty UA
    } else {
        // TODO: Client-side metrics for absence of UIWebView, we need to find a solution at this point
        // TODO: Considering auto-refresh
    }
    return nil;
}

- (NSString *)deviceId {
    if (!_deviceId) {
        _deviceId = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    }
    return _deviceId;
}

@end
