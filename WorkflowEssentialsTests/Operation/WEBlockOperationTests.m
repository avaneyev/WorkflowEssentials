//
//  WEBlockOperationTests.m
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <XCTest/XCTest.h>
#import <WorkflowEssentials/WEBlockOperation.h>
#import <WorkflowEssentials/WEOperationResult.h>

@interface WEBlockOperationTests : XCTestCase
@end

@implementation WEBlockOperationTests

- (void)testBlockOperationSynchronousBlock
{
    WEOperationResult<NSString *> *expectedResult = [[WEOperationResult alloc] initWithResult:@"some result"];
    
    // make a pointer to an operation to use inside a block to aboid a retain cycle.
    __unsafe_unretained __block WEBlockOperation *unsafeOperation = nil;
    WEBlockOperation<NSString *> *blockOperation = [[WEBlockOperation alloc] initWithName:nil requiresMainThread:YES block:^(void (^ _Nonnull completion)(WEOperationResult<NSString *> * _Nonnull)) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertTrue(unsafeOperation.active);
        
        completion(expectedResult);
    }];
    unsafeOperation = blockOperation;
    
    XCTAssertTrue(blockOperation.requiresMainThread);
    XCTAssertFalse(blockOperation.active);
    XCTAssertFalse(blockOperation.finished);
    XCTAssertFalse(blockOperation.cancelled);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for operation to complete"];
    
    [blockOperation startWithCompletion:^(WEOperationResult<NSString *> * _Nullable result) {
        XCTAssertTrue(unsafeOperation.finished);
        XCTAssertFalse(blockOperation.active);
        XCTAssertFalse(blockOperation.cancelled);
        
        XCTAssertEqual(result, expectedResult);
        
        [expectation fulfill];
    } completionQueue:dispatch_get_main_queue()];
    
    [self waitForExpectationsWithTimeout:0.1 handler:^(NSError * _Nullable error) {
        // retain the operation until completion.
        (void)blockOperation;
    }];
}

- (void)testBlockOperationAsyncBlock
{
    WEOperationResult<NSString *> *expectedResult = [[WEOperationResult alloc] initWithResult:@"some result"];
    
    // make a pointer to an operation to use inside a block to aboid a retain cycle.
    __unsafe_unretained __block WEBlockOperation *unsafeOperation = nil;
    WEBlockOperation<NSString *> *blockOperation = [[WEBlockOperation alloc] initWithName:nil requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult<NSString *> * _Nonnull)) {
        XCTAssertFalse([NSThread isMainThread]);
        XCTAssertTrue(unsafeOperation.active);
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completion(expectedResult);
        });
    }];
    unsafeOperation = blockOperation;
    
    XCTAssertFalse(blockOperation.requiresMainThread);
    XCTAssertFalse(blockOperation.active);
    XCTAssertFalse(blockOperation.finished);
    XCTAssertFalse(blockOperation.cancelled);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for operation to complete"];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [blockOperation startWithCompletion:^(WEOperationResult<NSString *> * _Nullable result) {
            XCTAssertTrue(unsafeOperation.finished);
            XCTAssertFalse(blockOperation.active);
            XCTAssertFalse(blockOperation.cancelled);
            
            XCTAssertEqual(result, expectedResult);

            [expectation fulfill];
        } completionQueue:dispatch_get_main_queue()];
    });
    
    [self waitForExpectationsWithTimeout:0.1 handler:^(NSError * _Nullable error) {
        // retain the operation until completion.
        (void)blockOperation;
    }];
}

@end
