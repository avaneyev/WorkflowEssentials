//
//  WEWorkflowTests.m
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <WorkflowEssentials/WEWorkflow.h>
#import <WorkflowEssentials/WEWorkflowContext.h>
#import <WorkflowEssentials/WEOperation.h>
#import <WorkflowEssentials/WEBlockOperation.h>

@interface WEWorkflowTests : XCTestCase
@end

@implementation WEWorkflowTests

- (void)testWorkflowInitialState
{
    WEWorkflow *workflow = [[WEWorkflow alloc] initWithContextClass:nil maximumConcurrentOperations:1];
    XCTAssertFalse(workflow.isActive);
    XCTAssertFalse(workflow.isCompleted);
    XCTAssertEqual(workflow.operationCount, 0);
    XCTAssertEqualObjects(workflow.operations, @[]);
}

- (void)testWorkflowSeveralOperationsAdded
{
    WEWorkflow *workflow = [[WEWorkflow alloc] initWithContextClass:nil maximumConcurrentOperations:1];
    WEBlockOperation *firstOperation = [[WEBlockOperation alloc] initWithName:nil requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        XCTFail(@"Should not start an operation until workflow had started");
    }];
    WEBlockOperation *secondOperation = [[WEBlockOperation alloc] initWithName:nil requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        XCTFail(@"Should not start an operation until workflow had started");
    }];
    
    [workflow addOperation:firstOperation];
    [workflow addOperation:secondOperation];
    
    XCTAssertEqual(workflow.operationCount, 2);
    NSArray *expectedOperations = @[ firstOperation, secondOperation ];
    XCTAssertEqualObjects(workflow.operations, expectedOperations);
    XCTAssertFalse(workflow.isActive);
    XCTAssertFalse(workflow.isCompleted);
}

- (void)testWorkflowSerialExecutionCompletesOperations
{
    WEOperationResult *firstResult = [[WEOperationResult alloc] initWithResult:@"result"];
    WEOperationResult *secondResult = [[WEOperationResult alloc] initWithError:[NSError errorWithDomain:@"1" code:2 userInfo:nil]];
    
    OCMockObject<WEWorkflowDelegate> *delegateMock = [OCMockObject mockForProtocol:@protocol(WEWorkflowDelegate)];
    
    WEWorkflow *workflow = [[WEWorkflow alloc] initWithContextClass:nil maximumConcurrentOperations:1 delegate:delegateMock delegateQueue:dispatch_get_main_queue()];
    __unsafe_unretained __block WEBlockOperation *unsafeFirstOperation;
    __unsafe_unretained __block WEBlockOperation *unsafeSecondOperation;
    
    WEBlockOperation *firstOperation = [[WEBlockOperation alloc] initWithName:nil requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        XCTAssertNotNil(unsafeSecondOperation);
        XCTAssertFalse(unsafeSecondOperation.active);
        XCTAssertFalse(unsafeSecondOperation.finished);
        XCTAssertFalse(unsafeSecondOperation.cancelled);
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completion(firstResult);
        });
    }];
    WEBlockOperation *secondOperation = [[WEBlockOperation alloc] initWithName:nil requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        XCTAssertNotNil(unsafeFirstOperation);
        XCTAssertFalse(unsafeFirstOperation.active);
        XCTAssertFalse(unsafeSecondOperation.finished);

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completion(secondResult);
        });
    }];
    
    unsafeFirstOperation = firstOperation;
    unsafeSecondOperation = secondOperation;
    
    [workflow addOperation:firstOperation];
    [workflow addOperation:secondOperation];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait until workflow completes"];
    
    [[[delegateMock expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
    }] workflowDidComplete:workflow];
        
    [workflow start];
    
    [self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
        XCTAssertTrue(workflow.completed);
    }];
}

@end
