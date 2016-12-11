//
//  WEWorkflow.m
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <WorkflowEssentials/WEWorkflow.h>
#import <WorkflowEssentials/WEWorkflowContext.h>
#import <WorkflowEssentials/WEOperation.h>

#import <pthread.h>
#import "WETools.h"
#import "WEWorkflowContext+Private.h"

typedef enum
{
    WEWorkflowInactive,
    WEWorkflowActive,
    WEWorkflowComplete
} WEWorkflowState;

@implementation WEWorkflow
{
    WEWorkflowContext *_context;
    NSUInteger _maximumConcurrentOperations;
    
    pthread_mutex_t _operationMutex;
    dispatch_queue_t _workflowInternalQueue;
    WEWorkflowState _state;
    NSMutableArray<WEOperation *> *_operations;
    NSMutableOrderedSet<WEOperation *> *_operationsReadyToExecute;
    NSMutableSet<WEOperation *> *_activeOperations;
}

- (instancetype)init
{
    return [self initWithContextClass:nil maximumConcurrentOperations:0];
}

- (instancetype)initWithContextClass:(Class)contextClass
         maximumConcurrentOperations:(NSUInteger)maximumConcurrentOperations
{
    Class defaultClass = [WEWorkflowContext class];
    if (contextClass != nil && contextClass != defaultClass && ![contextClass isSubclassOfClass:defaultClass])
    {
        THROW_INVALID_PARAM(contextClass, nil);
    }
    
    if (self = [super init])
    {
        if (contextClass == nil) contextClass = defaultClass;
        _context = [[contextClass alloc] initWithWorkflow:self];
        
        _maximumConcurrentOperations = (maximumConcurrentOperations > 0) ? maximumConcurrentOperations : INT32_MAX;
        
        pthread_mutex_init(&_operationMutex, NULL);
        _operations = [NSMutableArray new];
    }
    return self;
}

- (void)dealloc
{
    pthread_mutex_destroy(&_operationMutex);
}


#pragma mark - Properties

@synthesize context = _context;

- (BOOL)isActive
{
    BOOL isActive = NO;
    ENTER_CRITICAL_SECTION(self, _operationMutex)
    isActive = _state == WEWorkflowActive;
    LEAVE_CRITICAL_SECTION(self, _operationMutex)
    return isActive;
}

- (BOOL)isCompleted
{
    BOOL isCompleted = NO;
    ENTER_CRITICAL_SECTION(self, _operationMutex)
    isCompleted = _state == WEWorkflowComplete;
    LEAVE_CRITICAL_SECTION(self, _operationMutex)
    return isCompleted;
}

- (NSArray<WEOperation *> *)operations
{
    NSArray *operationsCopy;
    ENTER_CRITICAL_SECTION(self, _operationMutex)
        operationsCopy = [_operations copy];
    LEAVE_CRITICAL_SECTION(self, _operationMutex)
    return operationsCopy;
}

- (NSUInteger)operationCount
{
    NSUInteger count = 0;
    ENTER_CRITICAL_SECTION(self, _operationMutex)
        count = _operations.count;
    LEAVE_CRITICAL_SECTION(self, _operationMutex)
    return count;
}


#pragma mark - Operation Management

- (void)addOperation:(WEOperation *)operation
{
    // Never allow adding an operation as stand-alone while workflow is in progress, because it may be
    // picked up and start before any connections are added. Other means of adding operations should be used then.
    ENTER_CRITICAL_SECTION(self, _operationMutex)
   
    if (_state != WEWorkflowInactive)
    {
        THROW_INCONSISTENCY(@{ NSLocalizedDescriptionKey: @"Cannot directly add an operation after the workflow had started." });
    }
    
    [_operations addObject:operation];
    
    LEAVE_CRITICAL_SECTION(self, _operationMutex)
}


#pragma mark - Running the workflow

- (void)start
{
    ENTER_CRITICAL_SECTION(self, _operationMutex)
    if (_state == WEWorkflowInactive)
    {
        _workflowInternalQueue = dispatch_queue_create("we-workflow.queue", DISPATCH_QUEUE_SERIAL);
        _state = WEWorkflowActive;
        dispatch_async(_workflowInternalQueue, ^{
            [self _prepareAndStartWorkflow];
        });
    }
    LEAVE_CRITICAL_SECTION(self, _operationMutex)
}

#pragma mark - Workflow internals

- (void)_prepareAndStartWorkflow
{
    // Very first version - just perform operations in order they were added.
    // Will change later.
    
    NSArray<WEOperation *> *operations;
    ENTER_CRITICAL_SECTION(self, _operationMutex)
    
    WEAssert(_state == WEWorkflowActive);
    
    operations = [_operations copy];
    LEAVE_CRITICAL_SECTION(self, _operationMutex)
    
    if (operations.count == 0)
    {
        [self _completeWorkflow];
    }
    else
    {
        _operationsReadyToExecute = [[NSMutableOrderedSet alloc] initWithArray:operations];
        _activeOperations = [[NSMutableSet alloc] initWithCapacity:_maximumConcurrentOperations];
        [self _checkAndStartReadyOperation];
    }
}

static inline dispatch_queue_t _WEQueueForOperation(__unsafe_unretained WEOperation *operation)
{
    if (operation.requiresMainThread) return dispatch_get_main_queue();
    
    // TODO: make priority-based decision
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
}

- (void)_checkAndStartReadyOperation
{
    // There may not be any operations ready to execute - all operations that are not running are waiting,
    // or there are just running operations that are left.
    if (_operationsReadyToExecute.count == 0)
    {
        // If there are no operations ready and no operations active, either workflow is complete,
        // or it had gotten to a buggy state when it is not doing anything and cannot proceed.
        WEAssert(_activeOperations.count > 0);
        return;
    }
    
    // Only proceed if had not reached maximum number of operations allowed.
    if (_maximumConcurrentOperations > 0 && _activeOperations.count >= _maximumConcurrentOperations) return;
    
    WEOperation *firstReadyOperation = _operationsReadyToExecute.firstObject;
    [_operationsReadyToExecute removeObject:firstReadyOperation];
    WEAssert(firstReadyOperation != nil);
    WEAssert(!firstReadyOperation.active && !firstReadyOperation.finished && !firstReadyOperation.cancelled);
    
    [_activeOperations addObject:firstReadyOperation];
    
    dispatch_queue_t operationQueue = _WEQueueForOperation(firstReadyOperation);
    
    dispatch_async(operationQueue, ^{
        // TODO: pass explicit builder as the only facility an operation can amend the workflow.
        [firstReadyOperation prepareForExecutionWithContext:self->_context];
        dispatch_async(self->_workflowInternalQueue, ^{
            [self _runOperationIfStillPossible:firstReadyOperation onQueue:operationQueue];
        });
    });
    
    // Start operations until reached the maximum concurrent count.
    if (_operationsReadyToExecute.count > 0)
    {
        [self _checkAndStartReadyOperation];
    }
}

- (void)_runOperationIfStillPossible:(WEOperation *)operation onQueue:(dispatch_queue_t)queue
{
    WEAssert(operation != nil);
    WEAssert([_activeOperations containsObject:operation]);
    
    // TODO: if an operation cannot run after preparation, remove it from the list of active
    
    [_activeOperations addObject:operation];
    dispatch_async(queue, ^{
        [operation startWithCompletion:^(WEOperationResult * _Nullable result) {
            [self _completeOperation:operation withResult:result];
        } completionQueue:self->_workflowInternalQueue];
    });
}

- (void)_completeOperation:(WEOperation *)operation withResult:(WEOperationResult *)result
{
    WEAssert(operation != nil);
    WEAssert([_activeOperations containsObject:operation]);

    [_activeOperations removeObject:operation];
    NSString *operationName = operation.name;
    if (operationName != nil)
    {
        [_context _setOperationResult:result forOperationName:operationName];
    }
    
    // check if workflow is complete.
    // for now, since all operations are immediately ready, only check if something is active or waiting
    
    // TODO: check if any operations depending on the one just completed can now run
    
    if (_activeOperations.count == 0 && _operationsReadyToExecute.count == 0)
    {
        [self _completeWorkflow];
    }
    else
    {
        [self _checkAndStartReadyOperation];
    }
}

- (void)_completeWorkflow
{
    WEAssert(_activeOperations.count == 0);
    WEAssert(_operationsReadyToExecute.count == 0);
    
    ENTER_CRITICAL_SECTION(self, _operationMutex)
    
    WEAssert(_state == WEWorkflowActive);
    _state = WEWorkflowComplete;
    
    LEAVE_CRITICAL_SECTION(self, _operationMutex)
    
    // TODO: notify completion?
}

@end
