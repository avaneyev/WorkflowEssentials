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
#import <WorkflowEssentials/WEDependencyDescription.h>

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

    // The test tries to push the workflow to execute in parallel through the use of semaphores,
    // same way as in the parallel execution test, but expects that semaphore wait expires.
    
    WEOperationResult *firstResult = [[WEOperationResult alloc] initWithResult:@"result"];
    WEOperationResult *secondResult = [[WEOperationResult alloc] initWithError:[NSError errorWithDomain:@"1" code:2 userInfo:nil]];
    
    OCMockObject<WEWorkflowDelegate> *delegateMock = [OCMockObject mockForProtocol:@protocol(WEWorkflowDelegate)];
    
    WEWorkflow *workflow = [[WEWorkflow alloc] initWithContextClass:nil maximumConcurrentOperations:1 delegate:delegateMock delegateQueue:dispatch_get_main_queue()];
    __unsafe_unretained __block WEBlockOperation *unsafeFirstOperation;
    __unsafe_unretained __block WEBlockOperation *unsafeSecondOperation;
    
    dispatch_semaphore_t __block firstStartSemaphore = dispatch_semaphore_create(0);
    dispatch_semaphore_t __block secondStartSemaphore = dispatch_semaphore_create(0);
    uint64_t delay = (uint64_t)(200 * NSEC_PER_MSEC);

    WEBlockOperation *firstOperation = [[WEBlockOperation alloc] initWithName:nil requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        XCTAssertNotNil(unsafeSecondOperation);
        XCTAssertFalse(unsafeSecondOperation.active);
        XCTAssertFalse(unsafeSecondOperation.finished);
        XCTAssertFalse(unsafeSecondOperation.cancelled);

        dispatch_semaphore_signal(firstStartSemaphore);
        long result = dispatch_semaphore_wait(secondStartSemaphore, dispatch_time(DISPATCH_TIME_NOW, delay));
        XCTAssertNotEqual(result, 0);

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completion(firstResult);
        });
    }];
    WEBlockOperation *secondOperation = [[WEBlockOperation alloc] initWithName:nil requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        
        dispatch_semaphore_signal(secondStartSemaphore);

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

- (void)testWorkflowSerialExecutionSynchronousOperationCompletion
{
    // This test creates a serial workflow (at most one operation at a time)
    // with its operations completing synchronously.
    // It ensures that the workflow completes, finishes both operations
    
    WEOperationResult *firstResult = [[WEOperationResult alloc] initWithResult:@"result"];
    WEOperationResult *secondResult = [[WEOperationResult alloc] initWithError:[NSError errorWithDomain:@"1" code:2 userInfo:nil]];
    
    OCMockObject<WEWorkflowDelegate> *delegateMock = [OCMockObject mockForProtocol:@protocol(WEWorkflowDelegate)];
    
    WEWorkflow *workflow = [[WEWorkflow alloc] initWithContextClass:nil maximumConcurrentOperations:1 delegate:delegateMock delegateQueue:dispatch_get_main_queue()];
    WEBlockOperation *firstOperation = [[WEBlockOperation alloc] initWithName:nil requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        completion(firstResult);
    }];
    WEBlockOperation *secondOperation = [[WEBlockOperation alloc] initWithName:nil requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        completion(secondResult);
    }];
    
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
    
    [[delegateMock reject] workflow:[OCMArg any] didFailWithError:[OCMArg any]];
    
    [workflow start];
    
    [self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
        XCTAssertTrue(firstOperation.finished);
        XCTAssertEqual(firstOperation.result, firstResult);
        XCTAssertTrue(secondOperation.finished);
        XCTAssertEqual(secondOperation.result, secondResult);
        XCTAssertTrue(workflow.completed);
    }];
}

- (void)_testWorkflowSimpleDependencySourceByName:(BOOL)sourceByName targetByName:(BOOL)targetByName
{
    // This test creates a workflow with 3 operations: O1, O2 and O3, such that O2 depends on O1
    // and O3 is independent.
    
    WEOperationResult *r1 = [[WEOperationResult alloc] initWithResult:@"r1"];
    WEOperationResult *r2 = [[WEOperationResult alloc] initWithResult:@"r2"];
    WEOperationResult *r3 = [[WEOperationResult alloc] initWithResult:@"r3"];

    OCMockObject<WEWorkflowDelegate> *delegateMock = [OCMockObject mockForProtocol:@protocol(WEWorkflowDelegate)];
    
    WEBlockOperation *o1 = [[WEBlockOperation alloc] initWithName:@"o1" requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        completion(r1);
    }];
    WEBlockOperation *o2 = [[WEBlockOperation alloc] initWithName:@"o2" requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        XCTAssertTrue(o1.finished);
        completion(r2);
    }];
    WEBlockOperation *o3 = [[WEBlockOperation alloc] initWithName:@"o3" requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        completion(r3);
    }];

    WEWorkflow *workflow = [[WEWorkflow alloc] initWithContextClass:nil maximumConcurrentOperations:3 delegate:delegateMock delegateQueue:dispatch_get_main_queue()];
    
    [workflow addOperation:o1];
    [workflow addOperation:o2];
    [workflow addOperation:o3];
    
    WEDependencyDescription *dependency = [[WEDependencyDescription alloc] init];

    if (sourceByName) dependency.sourceOperationName = o1.name;
    else dependency.sourceOperation = o1;

    if (targetByName) dependency.targetOperationName = o2.name;
    else dependency.targetOperation = o2;
    
    [workflow addDependency:dependency];

    XCTestExpectation *expectation = [self expectationWithDescription:@"wait until workflow completes"];
    
    [[[delegateMock expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
    }] workflowDidComplete:workflow];
    
    [[delegateMock reject] workflow:[OCMArg any] didFailWithError:[OCMArg any]];
    
    [workflow start];
    
    [self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
        XCTAssertTrue(o1.finished);
        XCTAssertEqual(o1.result, r1);
        XCTAssertTrue(o2.finished);
        XCTAssertEqual(o2.result, r2);
        XCTAssertTrue(o3.finished);
        XCTAssertEqual(o3.result, r3);
        XCTAssertTrue(workflow.completed);
    }];
}

- (void)testWorkflowSimpleDependencySourceAndTargetByReference
{
    [self _testWorkflowSimpleDependencySourceByName:NO targetByName:NO];
}

- (void)testWorkflowSimpleDependencySourceAndTargetByName
{
    [self _testWorkflowSimpleDependencySourceByName:YES targetByName:YES];
}

- (void)testWorkflowSimpleDependencySourceByNameTargetByReference
{
    [self _testWorkflowSimpleDependencySourceByName:YES targetByName:NO];
}

- (void)testWorkflowSimpleDependencySourceByReferenceTargetByName
{
    [self _testWorkflowSimpleDependencySourceByName:NO targetByName:YES];
}

@end
