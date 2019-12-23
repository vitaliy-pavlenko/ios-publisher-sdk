//
//  CR_UsPrivacyConsentFunctionalTests.m
//  pubsdkTests
//
//  Created by Romain Lofaso on 12/11/19.
//  Copyright © 2019 Criteo. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CR_DataProtectionConsent.h"
#import "CR_DataProtectionConsentMock.h"
#import "Criteo+Testing.h"
#import "Criteo+Internal.h"
#import "CR_NetworkCaptor.h"
#import "CR_ApiHandler.h"
#import "CR_NetworkWaiter.h"
#import "CR_NetworkWaiterBuilder.h"
#import "NSURL+Testing.h"

#define CR_AssertDoNotContainsAppEventRequest(requests) \
do { \
    for (CR_HttpContent *content in requests) { \
        XCTAssertFalse([content.url testing_isAppLaunchEventUrlWithConfig:criteo.config]); \
    } \
} while (0);

@interface CR_UsPrivacyConsentFunctionalTests : XCTestCase

@property (nonatomic, strong) NSUserDefaults *userDefaults;

@end

@implementation CR_UsPrivacyConsentFunctionalTests

- (void)setUp
{
    self.userDefaults = [NSUserDefaults standardUserDefaults];
    [self.userDefaults removeObjectForKey:CR_DataProtectionConsentUsPrivacyIabConsentStringKey];
    [self.userDefaults removeObjectForKey:CR_DataProtectionConsentUsPrivacyCriteoStateKey];
}

- (void)tearDown {
    [self setUp];
}

- (void)testGivenIabConsentStringSet_whenCriteoRegister_thenUsIabSetInBidRequest
{
    [self.userDefaults setObject:CR_DataProtectionConsentMockDefaultUsPrivacyIabConsentString
                          forKey:CR_DataProtectionConsentUsPrivacyIabConsentStringKey];
    Criteo *criteo = [Criteo testing_criteoWithNetworkCaptor];

    [criteo testing_registerBannerAndWaitForHTTPResponses];

    NSString * actualConsent = [self _iabConsentInLastBidRequestWithCriteo:criteo];
    XCTAssertEqualObjects(actualConsent, CR_DataProtectionConsentMockDefaultUsPrivacyIabConsentString);
}

- (void)testGivenIabConsentStringSetWithoutConsent_whenCriteoRegister_thenUsIabSetInBidRequestAndAppEventNotSent
{
    [self.userDefaults setObject:@"1YYN"
                          forKey:CR_DataProtectionConsentUsPrivacyIabConsentStringKey];
    Criteo *criteo = [Criteo testing_criteoWithNetworkCaptor];

    [criteo testing_registerBanner];
    [self _waitForBidAndConfurationOnlyWithCriteo:criteo];

    NSString * actualConsent = [self _iabConsentInLastBidRequestWithCriteo:criteo];
    XCTAssertEqualObjects(actualConsent, @"1YYN");
    CR_AssertDoNotContainsAppEventRequest(criteo.testing_networkCaptor.allRequests);
}

- (void)testGivenIabConsentStringNil_whenCriteoRegister_thenUsIabNotSetInBidRequest
{
    Criteo *criteo = [Criteo testing_criteoWithNetworkCaptor];

    [criteo testing_registerBannerAndWaitForHTTPResponses];

    NSString * actualConsent = [self _iabConsentInLastBidRequestWithCriteo:criteo];
    XCTAssertNil(actualConsent);
}

- (void)testGivenIabConsentStringEmpty_whenCriteoRegister_thenUsIabNotSetInBidRequest
{
    [self.userDefaults setObject:@""
                          forKey:CR_DataProtectionConsentUsPrivacyIabConsentStringKey];
    Criteo *criteo = [Criteo testing_criteoWithNetworkCaptor];

    [criteo testing_registerBannerAndWaitForHTTPResponses];

    NSString * actualConsent = [self _iabConsentInLastBidRequestWithCriteo:criteo];
    XCTAssertNil(actualConsent);
}

- (void)testGivenCriteoUsPrivacyOptOutYES_whenCriteoRegister_thenBidIncludeUsPrivacyOptOutToYES_noAppEventSent
{
    Criteo *criteo = [Criteo testing_criteoWithNetworkCaptor];
    [criteo setUsPrivacyOptOut:YES];

    [criteo testing_registerBanner];
    [self _waitForBidAndConfurationOnlyWithCriteo:criteo];

    NSNumber *actualConsent = [self _criteoUsPrivacyConsentInLastBidRequestWithCriteo:criteo];
    XCTAssertTrue([actualConsent boolValue]);
    CR_AssertDoNotContainsAppEventRequest(criteo.testing_networkCaptor.allRequests);
}

- (void)testGivenCriteoUsPrivacyOptOutNO_whenCriteoRegister_thenBidIncludeUsPrivacyOptOutToNO_appEventSent
{
    Criteo *criteo = [Criteo testing_criteoWithNetworkCaptor];
    [criteo setUsPrivacyOptOut:NO];

    [criteo testing_registerBannerAndWaitForHTTPResponses];

    NSNumber *actualConsent = [self _criteoUsPrivacyConsentInLastBidRequestWithCriteo:criteo];
    XCTAssertNotNil(actualConsent);
    XCTAssertFalse([actualConsent boolValue]);
}

#pragma mark - Private methods

- (NSNumber *)_criteoUsPrivacyConsentInLastBidRequestWithCriteo:(Criteo *)criteo
{
    CR_HttpContent *bidRequest = criteo.testing_lastBidHttpContent;
    NSNumber *actualConsent = bidRequest.requestBody[CR_ApiHandlerUserKey][CR_ApiHandlerUspCriteoOptoutKey];
    return actualConsent;
}

- (NSString *)_iabConsentInLastBidRequestWithCriteo:(Criteo *)criteo
{
    CR_HttpContent *bidRequest = criteo.testing_lastBidHttpContent;
    NSString *actualConsent = bidRequest.requestBody[CR_ApiHandlerUserKey][CR_ApiHandlerUspIabStringKey];
    return actualConsent;
}

- (void)_waitForBidAndConfurationOnlyWithCriteo:(Criteo *)criteo {
    CR_NetworkWaiterBuilder *builder = [[CR_NetworkWaiterBuilder alloc] initWithConfig:criteo.config
                                                                         networkCaptor:criteo.testing_networkCaptor];
    CR_NetworkWaiter *waiter = builder  .withFinishedRequestsIncluded
                                        .withBid
                                        .withConfig
                                        .build;
    const BOOL result = [waiter wait];
    XCTAssert(result);
    sleep(1); // To be sure that the launch app event isn't sent asynchronously.
}

@end

