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



@end
