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
#import <WorkflowEssentials/WESegueDescription.h>

@interface WEWorkflowTests : XCTestCase
@end

@implementation WEWorkflowTests

#pragma mark - Workflow before starting

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

- (void)testWorkflowAddDependencyTwiceError
{
    WEWorkflow *workflow = [[WEWorkflow alloc] initWithContextClass:nil maximumConcurrentOperations:1];
    WEBlockOperation *operation = [[WEBlockOperation alloc] initWithName:nil requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        XCTFail(@"Should not start an operation until workflow had started");
    }];
    
    XCTAssertNoThrow([workflow addOperation:operation]);
    XCTAssertThrows([workflow addOperation:operation]);
}


#pragma mark - Workflow execution without dependencies

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


#pragma mark - Workflow with dependencies

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

- (void)_testWorkflowMultipleDependenciesWithMaximumConcurrent:(NSUInteger)maximumConcurrent
{
    // This test creates a workflow with 4 operations: O1, O2, O3 and O4,
    // such that O2 depends on all others and O3 depends on O1.
    // This test verifies that all dependencies are satisfied
    
    WEOperationResult *r1 = [[WEOperationResult alloc] initWithResult:@"r1"];
    WEOperationResult *r2 = [[WEOperationResult alloc] initWithResult:@"r2"];
    WEOperationResult *r3 = [[WEOperationResult alloc] initWithResult:@"r3"];
    WEOperationResult *r4 = [[WEOperationResult alloc] initWithResult:@"r4"];
    
    OCMockObject<WEWorkflowDelegate> *delegateMock = [OCMockObject mockForProtocol:@protocol(WEWorkflowDelegate)];
    
    WEBlockOperation *o1 = [[WEBlockOperation alloc] initWithName:@"o1" requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        completion(r1);
    }];
    WEBlockOperation *o3 = [[WEBlockOperation alloc] initWithName:@"o3" requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        XCTAssertTrue(o1.finished);
        completion(r3);
    }];
    WEBlockOperation *o4 = [[WEBlockOperation alloc] initWithName:@"o4" requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        completion(r4);
    }];
    WEBlockOperation *o2 = [[WEBlockOperation alloc] initWithName:@"o2" requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        XCTAssertTrue(o1.finished);
        XCTAssertTrue(o3.finished);
        XCTAssertTrue(o4.finished);
        completion(r2);
    }];
    
    WEWorkflow *workflow = [[WEWorkflow alloc] initWithContextClass:nil maximumConcurrentOperations:maximumConcurrent delegate:delegateMock delegateQueue:dispatch_get_main_queue()];
    
    [workflow addOperation:o1];
    [workflow addOperation:o2];
    [workflow addOperation:o3];
    [workflow addOperation:o4];
    
    [workflow addDependency:[WEDependencyDescription dependencyFormOperation:o1 toOperation:o2]];
    [workflow addDependency:[WEDependencyDescription dependencyFormOperation:o1 toOperation:o3]];
    [workflow addDependency:[WEDependencyDescription dependencyFormOperation:o3 toOperation:o2]];
    [workflow addDependency:[WEDependencyDescription dependencyFormOperationName:@"o4" toOperationName:@"o2"]];
    
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
        XCTAssertTrue(o4.finished);
        XCTAssertEqual(o4.result, r4);
        XCTAssertTrue(workflow.completed);
    }];
}

- (void)testWorkflowMultipleDependenciesSerial
{
    // Tests multiple dependencies on a serial workflow - operations are performed one by one, but
    // the one that depends on others is performed last.
    
    [self _testWorkflowMultipleDependenciesWithMaximumConcurrent:1];
}

- (void)testWorkflowMultipleDependenciesParallel
{
    // Tests multiple dependencies on a parallel workflow - operations may be parallelized, but
    // the one that depends on others is performed last.
    
    [self _testWorkflowMultipleDependenciesWithMaximumConcurrent:5];
}


#pragma mark - Dependency Error Handling

- (void)testWorkflowExplicitDependencyToUnownedOperationThrows
{
    WEWorkflow *workflow = [[WEWorkflow alloc] initWithContextClass:nil maximumConcurrentOperations:1];
    WEBlockOperation *operation = [[WEBlockOperation alloc] initWithName:nil requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        XCTFail(@"Should not start an operation until workflow had started");
    }];
    WEBlockOperation *unownedOperation = [[WEBlockOperation alloc] initWithName:nil requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        XCTFail(@"Should not start an operation until workflow had started");
    }];

    [workflow addOperation:operation];
    
    WEDependencyDescription *invalidDependency = [WEDependencyDescription dependencyFormOperation:operation toOperation:unownedOperation];
    
    XCTAssertThrows([workflow addDependency:invalidDependency]);
}

- (void)testWorkflowNamedOperationDependencyFailsToResolveOperation
{
    WEBlockOperation *firstOperation = [[WEBlockOperation alloc] initWithName:@"first" requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        XCTFail(@"Should not start an operation until workflow had started");
    }];
    WEBlockOperation *secondOperation = [[WEBlockOperation alloc] initWithName:@"second" requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        XCTFail(@"Should not start an operation until workflow had started");
    }];
 
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait until workflow completes"];

    OCMockObject<WEWorkflowDelegate> *delegateMock = [OCMockObject mockForProtocol:@protocol(WEWorkflowDelegate)];

    WEWorkflow *workflow = [[WEWorkflow alloc] initWithContextClass:nil maximumConcurrentOperations:5 delegate:delegateMock delegateQueue:dispatch_get_main_queue()];

    [[delegateMock reject] workflowDidComplete:workflow];
    [[[delegateMock expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
    }] workflow:workflow didFailWithError:[OCMArg checkWithBlock:^BOOL(NSError *e) {
        return [e.domain isEqualToString:WEWorkflowErrorDomain] && e.code == WEWorkflowInvalidDependency;
    }]];
    
    [workflow addOperation:firstOperation];
    [workflow addOperation:secondOperation];
    
    WEDependencyDescription *invalidDependency = [WEDependencyDescription dependencyFormOperationName:@"first" toOperationName:@"unknown"];
    XCTAssertNoThrow([workflow addDependency:invalidDependency]);
    
    [workflow start];

    [self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
        XCTAssertTrue(workflow.completed);
        XCTAssertNotNil(workflow.error);
    }];
}


#pragma mark - Workflow with Segues

- (void)_testWorkflowConditionalSegueFromError:(BOOL)fromError sourceByName:(BOOL)sourceByName targetByName:(BOOL)targetByName
{
    // This test creates a workflow with 3 operations: O1, O2 and O3, such that
    // - there is a conditional segue from O1 to O2 which activates on result being error;
    // - there is a conditional segue from O1 to O3 which activates on result not being error;
    // In other words, if O1 fails O2 is executed, otherwise O3 is executed.
    // Ensure that workflow completes and proper operations have proper results.
    
    WEOperationResult *r1 = fromError ? [[WEOperationResult alloc] initWithError:[NSError errorWithDomain:@"fake" code:-1 userInfo:nil]] : [[WEOperationResult alloc] initWithResult:@"r1"];
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
        XCTAssertTrue(o1.finished);
        completion(r3);
    }];
    
    WEWorkflow *workflow = [[WEWorkflow alloc] initWithContextClass:nil maximumConcurrentOperations:3 delegate:delegateMock delegateQueue:dispatch_get_main_queue()];
    
    [workflow addOperation:o1];
    [workflow addOperation:o2];
    [workflow addOperation:o3];

    WESegueDescription *errorSegue = [[WESegueDescription alloc] init];
    errorSegue.condition = [NSPredicate predicateWithBlock:^BOOL(WEOperationResult * _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return evaluatedObject.isFailed;
    }];
    WESegueDescription *successSegue = [[WESegueDescription alloc] init];
    successSegue.condition = [NSPredicate predicateWithBlock:^BOOL(WEOperationResult * _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return !evaluatedObject.isFailed;
    }];
    if (sourceByName)
    {
        errorSegue.sourceOperationName = o1.name;
        successSegue.sourceOperationName = o1.name;
    }
    else
    {
        errorSegue.sourceOperation = o1;
        successSegue.sourceOperation = o1;
    }
    
    if (targetByName)
    {
        errorSegue.targetOperationName = o2.name;
        successSegue.targetOperationName = o3.name;
    }
    else
    {
        errorSegue.targetOperation = o2;
        successSegue.targetOperation = o3;
    }
    
    [workflow addSegue:errorSegue];
    [workflow addSegue:successSegue];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait until workflow completes"];
    
    [[[delegateMock expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
    }] workflowDidComplete:workflow];
    
    [[delegateMock reject] workflow:[OCMArg any] didFailWithError:[OCMArg any]];
    
    [workflow start];
    
    [self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
        XCTAssertTrue(o1.finished);
        XCTAssertEqual(o1.result, r1);
        if (fromError)
        {
            XCTAssertTrue(o2.finished);
            XCTAssertEqual(o2.result, r2);

            XCTAssertFalse(o3.finished);
        }
        else
        {
            XCTAssertFalse(o2.finished);
            
            XCTAssertTrue(o3.finished);
            XCTAssertEqual(o3.result, r3);
        }
        XCTAssertTrue(workflow.completed);
    }];
}

- (void)testWorkflowConditionalSegueSourceByReferenceTargetByReference
{
    [self _testWorkflowConditionalSegueFromError:NO sourceByName:NO targetByName:NO];
}

- (void)testWorkflowConditionalSegueSourceByNameTargetByName
{
    [self _testWorkflowConditionalSegueFromError:NO sourceByName:YES targetByName:YES];
}

- (void)testWorkflowConditionalSegueOtherSideSourceByReferenceTargetByName
{
    [self _testWorkflowConditionalSegueFromError:YES sourceByName:NO targetByName:YES];
}


- (void)_testWorkflowConditionalAndUnconditionalSegueFromError:(BOOL)fromError
{
    // This test creates a workflow with 4 operations: O1, O2, O3 and O4, such that
    // - there is a conditional segue from O1 to O2 which activates on result being error;
    // - there is a conditional segue from O1 to O3 which activates on result not being error;
    // - there are 2 unconditional segues: O2 -> O4 and O3 -> O4;
    // In other words, if O1 fails O2 is executed, otherwise O3 is executed, and either way O4 follows.
    // Ensure that workflow completes and proper operations have proper results.
    
    WEOperationResult *r1 = fromError ? [[WEOperationResult alloc] initWithError:[NSError errorWithDomain:@"fake" code:-1 userInfo:nil]] : [[WEOperationResult alloc] initWithResult:@"r1"];
    WEOperationResult *r2 = [[WEOperationResult alloc] initWithResult:@"r2"];
    WEOperationResult *r3 = [[WEOperationResult alloc] initWithResult:@"r3"];
    WEOperationResult *r4 = [[WEOperationResult alloc] initWithResult:@"r4"];
    
    OCMockObject<WEWorkflowDelegate> *delegateMock = [OCMockObject mockForProtocol:@protocol(WEWorkflowDelegate)];
    
    WEBlockOperation *o1 = [[WEBlockOperation alloc] initWithName:@"o1" requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        completion(r1);
    }];
    WEBlockOperation *o2 = [[WEBlockOperation alloc] initWithName:@"o2" requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        XCTAssertTrue(o1.finished);
        completion(r2);
    }];
    WEBlockOperation *o3 = [[WEBlockOperation alloc] initWithName:@"o3" requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        XCTAssertTrue(o1.finished);
        completion(r3);
    }];
    WEBlockOperation *o4 = [[WEBlockOperation alloc] initWithName:@"o4" requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        WEOperation *o = fromError ? o2 : o3;
        XCTAssertTrue(o.finished);
        completion(r4);
    }];
    
    WEWorkflow *workflow = [[WEWorkflow alloc] initWithContextClass:nil maximumConcurrentOperations:3 delegate:delegateMock delegateQueue:dispatch_get_main_queue()];
    
    [workflow addOperation:o1];
    [workflow addOperation:o2];
    [workflow addOperation:o3];
    [workflow addOperation:o4];
    
    NSPredicate *errorCondition = [NSPredicate predicateWithBlock:^BOOL(WEOperationResult * _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return evaluatedObject.isFailed;
    }];
    WESegueDescription *errorSegue = [WESegueDescription segueFromOperationName:o1.name toOperationName:o2.name condition:errorCondition];

    NSPredicate *successCondition = [NSPredicate predicateWithBlock:^BOOL(WEOperationResult * _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return !evaluatedObject.isFailed;
    }];
    WESegueDescription *successSegue = [WESegueDescription segueFromOperationName:o1.name toOperationName:o3.name condition:successCondition];
    
    WESegueDescription *firstMergeSegue = [WESegueDescription segueFromOperationName:o2.name toOperationName:o4.name condition:nil];
    WESegueDescription *secondMergeSegue = [WESegueDescription segueFromOperationName:o3.name toOperationName:o4.name condition:nil];
    
    [workflow addSegue:errorSegue];
    [workflow addSegue:successSegue];
    [workflow addSegue:firstMergeSegue];
    [workflow addSegue:secondMergeSegue];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait until workflow completes"];
    
    [[[delegateMock expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
    }] workflowDidComplete:workflow];
    
    [[delegateMock reject] workflow:[OCMArg any] didFailWithError:[OCMArg any]];
    
    [workflow start];
    
    [self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
        XCTAssertTrue(o1.finished);
        XCTAssertEqual(o1.result, r1);
        if (fromError)
        {
            XCTAssertTrue(o2.finished);
            XCTAssertEqual(o2.result, r2);

            XCTAssertFalse(o3.finished);
        }
        else
        {
            XCTAssertFalse(o2.finished);

            XCTAssertTrue(o3.finished);
            XCTAssertEqual(o3.result, r3);
        }
        XCTAssertTrue(o4.finished);
        XCTAssertEqual(o4.result, r4);

        XCTAssertTrue(workflow.completed);
    }];
}

- (void)testWorkflowConditionalAndUnconditionalSegue
{
    [self _testWorkflowConditionalAndUnconditionalSegueFromError:NO];
    [self _testWorkflowConditionalAndUnconditionalSegueFromError:YES];
}

- (void)testWorkflowSeguesAndDependencies
{
    // This test creates a workflow with 4 operations: O1, O2, O3 and O4 with the following connections:
    // Unconditional segue O1 -> O2
    // Unconditional segue O1 -> O3
    // Conditional segue with a condition that is always false O1 -> O4
    // Dependency O2 -> O3
    // Dependency O2 -> O4
    // Expected behavior is to run the operations in the following order: O1 -> O2 -> O3, because:
    // - O1 is independent and can start
    // - O2 is started once a segue to it activates
    // - O3 does not start until its dependency (O2) completes, even though segue from O1 was activated
    // - O4 does not run at all because none of the incoming segues ever activate, even though its dependencies (O2)
    //   have completed
    
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
        XCTAssertTrue(o1.finished);
        XCTAssertTrue(o2.finished);
        completion(r3);
    }];
    WEBlockOperation *o4 = [[WEBlockOperation alloc] initWithName:@"o4" requiresMainThread:NO block:^(void (^ _Nonnull completion)(WEOperationResult * _Nonnull)) {
        XCTFail(@"This should never run, see comment in the test header describing why.");
    }];
    
    WEWorkflow *workflow = [[WEWorkflow alloc] initWithContextClass:nil maximumConcurrentOperations:3 delegate:delegateMock delegateQueue:dispatch_get_main_queue()];
    
    [workflow addOperation:o1];
    [workflow addOperation:o2];
    [workflow addOperation:o3];
    [workflow addOperation:o4];
    
    NSPredicate *alwaysFailingCondition = [NSPredicate predicateWithBlock:^BOOL(WEOperationResult * _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return NO;
    }];
    WESegueDescription *firstSegue = [WESegueDescription segueFromOperationName:o1.name toOperationName:o2.name condition:nil];
    WESegueDescription *secondSegue = [WESegueDescription segueFromOperationName:o2.name toOperationName:o3.name condition:nil];
    WESegueDescription *neverActivatedSegue = [WESegueDescription segueFromOperationName:o1.name toOperationName:o4.name condition:alwaysFailingCondition];

    WEDependencyDescription *firstDependency = [WEDependencyDescription dependencyFormOperationName:o2.name toOperationName:o3.name];
    WEDependencyDescription *secondDependency = [WEDependencyDescription dependencyFormOperationName:o2.name toOperationName:o4.name];
    
    [workflow addSegue:firstSegue];
    [workflow addSegue:secondSegue];
    [workflow addSegue:neverActivatedSegue];
    [workflow addDependency:firstDependency];
    [workflow addDependency:secondDependency];
    
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
    }];
}

@end
