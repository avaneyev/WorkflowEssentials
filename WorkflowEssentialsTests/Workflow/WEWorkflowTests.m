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
    // This test adds several operations but does not start the workflow
    // It ensures that counts are correct and operations were not started
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
    // This test creates a serial workflow (at most one operation at a time)
    // It ensures that the workflow completes, finishes both operations
    // It also verifies that operations are performed one after another
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
        XCTAssertTrue(unsafeFirstOperation.finished);
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
        XCTAssertTrue(firstOperation.finished);
        XCTAssertEqual(firstOperation.result, firstResult);
        XCTAssertTrue(secondOperation.finished);
        XCTAssertEqual(secondOperation.result, secondResult);
        XCTAssertTrue(workflow.completed);
    }];
}

- (void)testWorkflowParallelExecutionOperations
{
    // This test creates a parallel workflow and ensures that 2 operations can run at the same time.
    // To make a strong check, the test uses a pair of semaphores.
    // Each operation starts one and waits for another to be signaled.
    // If the operations were not performed in parallel, one would wait for the other semaphore and never succeed.
    
    WEOperationResult *firstResult = [[WEOperationResult alloc] initWithResult:@"result"];
    WEOperationResult *secondResult = [[WEOperationResult alloc] initWithError:[NSError errorWithDomain:@"1" code:2 userInfo:nil]];
    
    OCMockObject<WEWorkflowDelegate> *delegateMock = [OCMockObject mockForProtocol:@protocol(WEWorkflowDelegate)];
    
    WEWorkflow *workflow = [[WEWorkflow alloc] initWithContextClass:nil maximumConcurrentOperations:3 delegate:delegateMock delegateQueue:dispatch_get_main_queue()];
    __unsafe_unretained __block WEBlockOperation *unsafeFirstOperation;
    __unsafe_unretained __block WEBlockOperation *unsafeSecondOperation;
    
    dispatch_semaphore_t __block firstStartSemaphore = dispatch_semaphore_create(0);
    dispatch_semaphore_t __block secondStartSemaphore = dispatch_semaphore_create(0);
    uint64_t delay = (uint64_t)(200 * NSEC_PER_MSEC);
    
    WEBlockOperation *firstOperation = [[WEBlockOperation alloc] initWithName:nil requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        dispatch_semaphore_signal(firstStartSemaphore);
        long result = dispatch_semaphore_wait(secondStartSemaphore, dispatch_time(DISPATCH_TIME_NOW, delay));
        XCTAssertEqual(result, 0);
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completion(firstResult);
        });
    }];
    WEBlockOperation *secondOperation = [[WEBlockOperation alloc] initWithName:nil requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        dispatch_semaphore_signal(secondStartSemaphore);
        long result = dispatch_semaphore_wait(firstStartSemaphore, dispatch_time(DISPATCH_TIME_NOW, delay));
        XCTAssertEqual(result, 0);
        
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
        XCTAssertTrue(firstOperation.finished);
        XCTAssertEqual(firstOperation.result, firstResult);
        XCTAssertTrue(secondOperation.finished);
        XCTAssertEqual(secondOperation.result, secondResult);
        XCTAssertTrue(workflow.completed);
    }];
}

@end
