//
//  WEWorkflow.h
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <Foundation/Foundation.h>

@class WEWorkflowContext;
@class WEOperation;

@interface WEWorkflow : NSObject

/**
 Initialize a new workflow
 @param contextClass a context class, which must be a subclass of `WEWorkflowContext` or `nil`
 @param maximumConcurrentOperations maximum number of operations that may be executed concurrently
 @return an instance of `WEWorkflow`
 */
- (nonnull instancetype)initWithContextClass:(nullable Class)contextClass
                 maximumConcurrentOperations:(NSUInteger)maximumConcurrentOperations NS_DESIGNATED_INITIALIZER;

/**
 returns YES if the workflow is active, and NO otherwise
 */
@property (nonatomic, readonly, getter=isActive) BOOL active;

/**
 Workflow context, and object that stores completed operation result and arbitrary workflow context
 */
@property (nonatomic, readonly, strong, nonnull) WEWorkflowContext *context;

/**
 An array of operations added to the workflow
 */
@property (nonatomic, readonly, nonnull) NSArray<WEOperation *> *operations;

/**
 Total number of operations that were added to the workflow.
 */
@property (nonatomic, readonly) NSUInteger operationCount;

@end
