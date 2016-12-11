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
    
    WEWorkflow *workflow = [[WEWorkflow alloc] initWithContextClass:nil maximumConcurrentOperations:1];
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
    
    NSPredicate *workflowCompletionPredicate = [NSPredicate predicateWithBlock:^BOOL(id _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        if (evaluatedObject == nil || ![evaluatedObject isKindOfClass:[WEWorkflow class]]) return NO;
        WEWorkflow *w = evaluatedObject;
        return w.completed;
    }];
    
    [self expectationForPredicate:workflowCompletionPredicate evaluatedWithObject:workflow handler:nil];
    
    [workflow start];
    
    [self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
        XCTAssertTrue(workflow.completed);
    }];
}

@end
