//
//  WEOperation.h
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <Foundation/Foundation.h>

@class WEWorkflowContext;
@class WEOperationResult;

@interface WEOperation : NSObject

- (nonnull instancetype)initWithName:(nullable NSString *)name NS_DESIGNATED_INITIALIZER;


#pragma mark - Overridables

/**
 An operation should return YES if it requires main thread for execution, otherwise it should return NO.
 Operations that require main thread will be performed on the main queue, other operations will be
 dispatched to background queues based on other preferences.
 NOTE that unlike with dispatch/operation queues, workflow may execute more than one operation that
 requires main queue if they are async and don't depend on each other.
 */
@property (nonatomic, readonly) BOOL requiresMainThread;

/**
 Called when the workflow is ready to start an operation, but before the start.
 Allows an operation to to prepare itself for execution.
 This gives an operation a chance to check its prerequisites and schedule additional work to be done
 before the operation is performed.
 Default implementation does nothing.
 */
- (void)prepareForExecutionWithContext:(nonnull __kindof WEWorkflowContext *)context;

/**
 Overridable method starting the operation. Subclasses must implement this method. Default implementation throws an exception.
 */
- (void)start;


#pragma mark - Operation state

/**
 Optional operation name that can be used by other operations to its result or
 the operation itself as a dependency.
 */
@property (nonatomic, readonly, retain, nullable) NSString *name;

/**
 Returns YES if the operation is active (in progress) and NO otherwise.
 */
@property (nonatomic, readonly, getter=isActive) BOOL active;

/**
 Returns YES if the operation is finished (completed, successfully or with an error) and NO otherwise.
 */
@property (nonatomic, readonly, getter=isFinished) BOOL finished;

/**
 Returns YES if the operation is cancelled and NO otherwise.
 */
@property (nonatomic, readonly, getter=isCancelled) BOOL cancelled;

/**
 Starts the operation
 @param completion completion block that needs to be invoked when the operation completes
 @discussion This method will be called by the workflow. 
 If an operation is started manually, this method should be called. 
 It updates the state and invokes `start` method, which should be overridden by subclasses to start an actual operation.
 */
- (void)startWithCompletion:(nullable void (^)(WEOperationResult * _Nullable result))completion completionQueue:(nullable dispatch_queue_t)completionQueue;

/**
 Marks operation as complete with appropriate result.
 @param result Operation result
 @discussion a subclass must call this method when an operation is complete.
 It will update the operation state and invoke a callback.
 */
- (void)completeWithResult:(nullable WEOperationResult *)result;

@end
