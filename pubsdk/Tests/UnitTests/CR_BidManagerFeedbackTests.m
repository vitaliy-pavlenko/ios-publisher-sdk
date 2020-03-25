//
//  CR_BidManagerFeedbackTests.m
//  pubsdkTests
//
//  Created by Aleksandr Pakhmutov on 25/03/2020.
//  Copyright © 2020 Criteo. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock.h>
#import "pubsdkTests-Swift.h"
#import "CR_CdbRequest.h"
#import "CR_CdbResponse.h"
#import "CR_CdbBid.h"
#import "CR_CdbBidBuilder.h"
#import "CR_BidManagerBuilder.h"
#import "CR_DeviceInfoMock.h"

@interface CR_BidManagerFeedbackTests : XCTestCase

@property (nonatomic, strong) CR_CacheAdUnit *adUnit;
@property (nonatomic, strong) CR_CdbRequest *cdbRequest;
@property (nonatomic, strong) NSString *impressionId;
@property (nonatomic, strong) CR_CdbBid *validBid;
@property (nonatomic, strong) CR_CdbResponse *cdbResponse;

@property (nonatomic, strong) CR_CacheAdUnit *adUnitForInvalidBid;
@property (nonatomic, strong) CR_CdbRequest *cdbRequestForInvalidBid;
@property (nonatomic, strong) NSString *impressionIdForInvalidBid;
@property (nonatomic, strong) CR_CdbBid *invalidBid;
@property (nonatomic, strong) CR_CdbResponse *cdbResponseWithInvalidBid;

@property (nonatomic, strong) CR_FeedbackFileManagingMock *feedbackFileManagingMock;
@property (nonatomic, strong) CASObjectQueue *feedbackSendingQueue;
@property (nonatomic, strong) CR_BidManager *bidManager;
@property (nonatomic, strong) CR_CacheManager *cacheManager;
@property (nonatomic, strong) CR_ApiHandler *apiHandlerMock;

@end

@implementation CR_BidManagerFeedbackTests

- (void)setUp {
    self.apiHandlerMock = OCMClassMock([CR_ApiHandler class]);
    self.cacheManager = [[CR_CacheManager alloc] init];
    self.feedbackFileManagingMock = [[CR_FeedbackFileManagingMock alloc] init];
    self.feedbackFileManagingMock.useReadWriteDictionary = YES;
    self.feedbackSendingQueue = [[CASInMemoryObjectQueue alloc] init];
    CR_FeedbackStorage *feedbackStorage = [[CR_FeedbackStorage alloc] initWithFileManager:self.feedbackFileManagingMock
                                                                                withQueue:self.feedbackSendingQueue];

    CR_BidManagerBuilder *builder = [[CR_BidManagerBuilder alloc] init];
    builder.deviceInfo = [[CR_DeviceInfoMock alloc] init];
    builder.apiHandler = self.apiHandlerMock;
    builder.cacheManager = self.cacheManager;
    builder.feedbackStorage = feedbackStorage;

    self.bidManager = [builder buildBidManager];

    self.adUnit = [[CR_CacheAdUnit alloc] initWithAdUnitId:@"adUnitForValid" width:300 height:250];
    self.cdbRequest = [[CR_CdbRequest alloc] initWithAdUnits:@[self.adUnit]];
    self.impressionId = [self.cdbRequest impressionIdForAdUnit:self.adUnit];
    self.validBid = CR_CdbBidBuilder.new.adUnit(self.adUnit).impressionId(self.impressionId).build;
    self.cdbResponse = [[CR_CdbResponse alloc] init];
    self.cdbResponse.cdbBids = @[self.validBid];

    self.adUnitForInvalidBid = [[CR_CacheAdUnit alloc] initWithAdUnitId:@"adUnitForInvalid" width:300 height:250];
    self.cdbRequestForInvalidBid = [[CR_CdbRequest alloc] initWithAdUnits:@[self.adUnitForInvalidBid]];
    self.impressionIdForInvalidBid = [self.cdbRequestForInvalidBid impressionIdForAdUnit:self.adUnitForInvalidBid];
    self.invalidBid = CR_CdbBidBuilder.new.adUnit(self.adUnitForInvalidBid).impressionId(self.impressionIdForInvalidBid).cpm(@"-99.00").build;
    self.cdbResponseWithInvalidBid = [[CR_CdbResponse alloc] init];
    self.cdbResponseWithInvalidBid.cdbBids = @[self.invalidBid];

    NSUInteger messageCount = [feedbackStorage messagesReadyToSend].count;
    [feedbackStorage removeFirstMessagesWithCount:messageCount];
    XCTAssertEqual([feedbackStorage messagesReadyToSend].count, 0);
}

- (void)testFetchingBids_ShouldUpdateCdbCallStart {
    [self configureApiHandlerMockWithCdbRequest:self.cdbRequest cdbResponse:self.cdbResponse error:nil];
    [self.bidManager prefetchBid:self.adUnit];

    CR_FeedbackMessage *message = [[self.feedbackFileManagingMock writeFeedbackResults] lastObject];
    XCTAssertNotNil(message);
    XCTAssertNotNil(message.cdbCallStartTimestamp);
}

- (void)testFetrchingBidsThatIsMissingInResponse_ShouldUpdateCdbCallEnd_AndMoveToSendingQueue {
    self.cdbResponse.cdbBids = @[];

    [self configureApiHandlerMockWithCdbRequest:self.cdbRequest cdbResponse:self.cdbResponse error:nil];

    [self.bidManager prefetchBid:self.adUnit];

    XCTAssertEqual([self.feedbackSendingQueue size], 1);
    CR_FeedbackMessage *message = [self.feedbackSendingQueue peek:1][0];
    XCTAssertNotNil(message.cdbCallEndTimestamp);
}

- (void)testFetching_TimeoutError_ShouldUpdateTimeoutFlagTrue_AndMoveToSendingQueue {
    NSError *error = [[NSError alloc] initWithDomain:NSCocoaErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    [self configureApiHandlerMockWithCdbRequest:self.cdbRequest cdbResponse:nil error:error];

    [self.bidManager prefetchBid:self.adUnit];

    XCTAssertEqual([self.feedbackSendingQueue size], 1);
    CR_FeedbackMessage *message = [self.feedbackSendingQueue peek:1][0];
    XCTAssertNil(message.cdbCallEndTimestamp);
    XCTAssertTrue(message.isTimeouted);
}

- (void)testFetching_OtherError_ShouldUpdateTimeoutFlagFalse_AndMoveToSendingQueue {
    NSError *error = [[NSError alloc] initWithDomain:NSCocoaErrorDomain code:(NSURLErrorTimedOut + 1) userInfo:nil];
    [self configureApiHandlerMockWithCdbRequest:self.cdbRequest cdbResponse:nil error:error];

    [self.bidManager prefetchBid:self.adUnit];

    XCTAssertEqual([self.feedbackSendingQueue size], 1);
    CR_FeedbackMessage *message = [self.feedbackSendingQueue peek:1][0];
    XCTAssertNil(message.cdbCallEndTimestamp);
    XCTAssertFalse(message.isTimeouted);
}

- (void)testFetchedValidBid_ShouldUpdateCdbCallEndAndImpressionId {
    [self configureApiHandlerMockWithCdbRequest:self.cdbRequest cdbResponse:self.cdbResponse error:nil];

    [self.bidManager prefetchBid:self.adUnit];

    CR_FeedbackMessage *message = [[self.feedbackFileManagingMock writeFeedbackResults] lastObject];
    XCTAssertNotNil(message);
    XCTAssertNotNil(message.cdbCallEndTimestamp);
    XCTAssertEqualObjects(message.impressionId, self.impressionId);
}

- (void)testFetchedInvalidBid_ShouldMoveToSendingQueue {
    [self configureApiHandlerMockWithCdbRequest:self.cdbRequestForInvalidBid cdbResponse:self.cdbResponseWithInvalidBid error:nil];

    [self.bidManager prefetchBid:self.adUnitForInvalidBid];

    XCTAssertEqual([self.feedbackSendingQueue size], 1);
    CR_FeedbackMessage *message = [self.feedbackSendingQueue peek:1][0];
    XCTAssertNil(message.cdbCallEndTimestamp);
    XCTAssertEqualObjects(self.feedbackFileManagingMock.removeRequestedFilenames[0], self.impressionIdForInvalidBid);
}

- (void)testConsumeValidBid_ShouldMoveToSendingQueue_WithUpdatedElapsedTimestamp {
    self.cacheManager.bidCache[self.adUnit] = self.validBid;
    [self.bidManager getBid:self.adUnit];

    XCTAssertEqual([self.feedbackSendingQueue size], 1);
    CR_FeedbackMessage *message = [self.feedbackSendingQueue peek:1][0];
    XCTAssertNotNil(message.elapsedTimestamp);
}

- (void)testConsumeExpiredBid_ShouldMoveToSendingQueue_WithoutUpdateOfElapsedTimestamp {
    CR_CdbBid *expiredBid = CR_CdbBidBuilder.new.adUnit(self.adUnit).ttl(-1).build;
    self.cacheManager.bidCache[self.adUnit] = expiredBid;
    [self.bidManager getBid:self.adUnit];

    XCTAssertEqual([self.feedbackSendingQueue size], 1);
    CR_FeedbackMessage *message = [self.feedbackSendingQueue peek:1][0];
    XCTAssertNil(message.elapsedTimestamp);
}

#pragma mark - Private

- (void)configureApiHandlerMockWithCdbRequest:(CR_CdbRequest * _Nullable)cdbRequest
                                  cdbResponse:(CR_CdbResponse * _Nullable)cdbResponse
                                        error:(NSError * _Nullable)error {
    id completion0 = [OCMArg invokeBlockWithArgs:cdbRequest, nil];
    id completion1 = [OCMArg invokeBlockWithArgs:
                 (cdbRequest ? cdbRequest : [NSNull  null]),
                 (cdbResponse ? cdbResponse : [NSNull  null]),
                 (error ? error : [NSNull null]),
                 nil];
    OCMStub([self.apiHandlerMock callCdb:[OCMArg any]
                                 consent:[OCMArg any]
                                  config:[OCMArg any]
                              deviceInfo:[OCMArg any]
                           beforeCdbCall:completion0
                       completionHandler:completion1]);
}

@end
