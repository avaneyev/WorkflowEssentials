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
}

- (void)_completeWorkflow
{
    // TODO: notify completion?
}

@end
