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
@class WEDependencyDescription;
@class WESegueDescription;

@class WEWorkflow;

FOUNDATION_EXPORT NSString *const _Nonnull WEWorkflowErrorDomain;
FOUNDATION_EXPORT NSInteger const WEWorkflowInvalidDependency;
FOUNDATION_EXPORT NSInteger const WEWorkflowDependencyCycle;
FOUNDATION_EXPORT NSInteger const WEWorkflowDeadlocked;
FOUNDATION_EXPORT NSInteger const WEWorkflowDuplicateNames;
FOUNDATION_EXPORT NSInteger const WEWorkflowInvalidSegue;

@protocol WEWorkflowDelegate <NSObject>

/**
 Sent when workflow successfully completes.
 */
- (void)workflowDidComplete:(nonnull WEWorkflow *)workflow;

/**
 Sent when workflow fails with an error.
 */
- (void)workflow:(nonnull WEWorkflow *)workflow didFailWithError:(nonnull NSError *)error;

@end

@interface WEWorkflow : NSObject

/**
 Initialize a new workflow
 @param contextClass a context class, which must be a subclass of `WEWorkflowContext` or `nil`
 @param maximumConcurrentOperations maximum number of operations that may be executed concurrently
 @return an instance of `WEWorkflow`
 */
- (nonnull instancetype)initWithContextClass:(nullable Class)contextClass
                 maximumConcurrentOperations:(NSUInteger)maximumConcurrentOperations;

/**
 Initialize a new workflow
 @param contextClass a context class, which must be a subclass of `WEWorkflowContext` or `nil`
 @param maximumConcurrentOperations maximum number of operations that may be executed concurrently
 @param delegate workflow delegate that will be notified of certain workflow events
 @param delegateQueue a dispatch queue to be used for sending delegate events. Must be provided when a delegate is specified.
 @return an instance of `WEWorkflow`
 */
- (nonnull instancetype)initWithContextClass:(nullable Class)contextClass
                 maximumConcurrentOperations:(NSUInteger)maximumConcurrentOperations
                                    delegate:(nullable id<WEWorkflowDelegate>)delegate
                               delegateQueue:(nullable dispatch_queue_t)delegateQueue NS_DESIGNATED_INITIALIZER;

/**
 returns YES if the workflow is active, and NO otherwise
 */
@property (nonatomic, readonly, getter=isActive) BOOL active;

/**
 returns YES if the workflow has been completed, and NO otherwise
 */
@property (nonatomic, readonly, getter=isCompleted) BOOL completed;

/**
 returns YES if the workflow had failed, and NO otherwise
 */
@property (nonatomic, readonly, getter=isFailed) BOOL failed;

/**
 returns an error if the workflow failed
 */
@property (nonatomic, readonly, nullable) NSError *error;

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

/**
 Adds a single operation
 @param operation an operation to add
 */
- (void)addOperation:(nonnull WEOperation *)operation;

/**
 Add a dependency. Specifies that one operation depends on another.
 @param dependency describes the dependency to be added.
 @discussion dependency description will go through a set of quick sanity checks before being added.
 Dependency will be copied by the workflow.
 */
- (void)addDependency:(nonnull WEDependencyDescription *)dependency;

/**
 Add a segue. Specifies that one operation is conditionally set to start when another one completes.
 Segue may specify a condition (evaluated on its source operation result), if it does, the condition
 must evaluate to YES for the target operation to be set as ready to start.
 @param segue describes the segue to be added.
 @discussion segue description will go through a set of quick sanity checks before being added.
 Segue will be copied by the workflow.
 */
- (void)addSegue:(nonnull WESegueDescription *)segue;

/**
 Starts executing the workflow
 */
- (void)start;

@end
