//
//  WEOperationTests.m
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <XCTest/XCTest.h>
#import <WorkflowEssentials/WEOperation.h>
#import <WorkflowEssentials/WEOperationResult.h>

static NSString *const WEOperationSimpleSubclassResult = @"WEOperationSimpleSubclass";

@interface WEOperationSimpleSubclass : WEOperation<NSString *>
@end

@implementation WEOperationSimpleSubclass

- (void)start
{
    dispatch_async(dispatch_get_main_queue(), ^{
        WEOperationResult<NSString *> *result = [[WEOperationResult alloc] initWithResult:WEOperationSimpleSubclassResult];
        [self completeWithResult:result];
    });
}

@end

@interface WEOperationTests : XCTestCase
@end

@implementation WEOperationTests

- (void)testSimpleOperationInitialState
{
    WEOperationSimpleSubclass *operation = [[WEOperationSimpleSubclass alloc] initWithName:@"operationName"];
    
    XCTAssertFalse(operation.finished);
    XCTAssertFalse(operation.active);
    XCTAssertFalse(operation.cancelled);
    XCTAssertEqualObjects(operation.name, @"operationName");
}

- (void)testSimpleOperationToCompletion
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait until operation completes"];
    WEOperationSimpleSubclass *operation = [[WEOperationSimpleSubclass alloc] initWithName:@"operationName"];
    [operation startWithCompletion:^(WEOperationResult<NSString *> * _Nullable result) {
        XCTAssert(operation.finished);
        
        WEOperationResult<NSString *> *operationResult = operation.result;
        XCTAssertNotNil(operationResult);
        XCTAssertEqualObjects(operationResult.result, WEOperationSimpleSubclassResult);
        
        [expectation fulfill];
    } completionQueue:dispatch_get_main_queue()];
    
    [self waitForExpectationsWithTimeout:0.5 handler:^(NSError *error) {
        // retain operation until completion
        (void)operation;
    }];
}

@end
