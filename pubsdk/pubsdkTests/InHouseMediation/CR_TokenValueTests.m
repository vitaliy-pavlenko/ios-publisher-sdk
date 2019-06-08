//
//  CR_TokenValueTests.m
//  pubsdkTests
//
//  Created by Sneha Pathrose on 6/4/19.
//  Copyright © 2019 Criteo. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CR_TokenValue.h"
#import "CRAdUnit.h"
#import "CRAdUnit+Internal.h"

@interface CR_TokenValueTests : XCTestCase

@end

@implementation CR_TokenValueTests

- (void)testTokenValueInitialization {
    NSString *expectedDisplayURL = @"expectedDisplayURL";
    NSDate *expectedInsertTime = [NSDate date];
    NSTimeInterval expectedTtl = 500;
    CRAdUnitType expectedAdUnitType = CRAdUnitTypeBanner;
    CR_TokenValue *tokenValue = [[CR_TokenValue alloc] initWithDisplayURL:expectedDisplayURL insertTime:expectedInsertTime ttl:expectedTtl adUnitType:expectedAdUnitType];
    XCTAssertEqual(tokenValue.displayUrl, expectedDisplayURL);
    XCTAssertEqual(tokenValue.ttl, expectedTtl);
    XCTAssertEqual(tokenValue.insertTime, expectedInsertTime);
    XCTAssertEqual(tokenValue.adUnitType, expectedAdUnitType);
}

- (void)testTokenValueExpired {
     CR_TokenValue *tokenValue = [[CR_TokenValue alloc] initWithDisplayURL:@"123"
                                                                insertTime:[[NSDate alloc] initWithTimeIntervalSinceNow:-400]
                                                                       ttl:200
                                                                adUnitType:CRAdUnitTypeBanner];
    XCTAssertTrue([tokenValue isExpired]);
}

- (void)testTokenValueNotExpired {
    CR_TokenValue *tokenValue = [[CR_TokenValue alloc] initWithDisplayURL:@"123"
                                                               insertTime:[[NSDate alloc] initWithTimeIntervalSinceNow:-100]
                                                                      ttl:200
                                                               adUnitType:CRAdUnitTypeBanner];
    XCTAssertFalse([tokenValue isExpired]);
}

@end