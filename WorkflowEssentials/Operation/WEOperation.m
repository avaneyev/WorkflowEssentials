//
//  WEOperation.m
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <WorkflowEssentials/WEOperation.h>
#import <pthread.h>
#import <objc/runtime.h>
#import "WETools.h"

typedef enum
{
    WEOperationUnknown,
    WEOperationInactive,
    WEOperationActive,
    WEOperationComplete,
    WEOperationCancelled,
} WEOperationState;

@implementation WEOperation
{
    pthread_mutex_t _mutex;
    WEOperationState _state;
    NSString *_name;
    void (^_completion)(WEOperationResult *result);
    dispatch_queue_t _completionQueue;
}

@synthesize name = _name;

- (instancetype)init
{
    return [self initWithName:nil];
}

- (instancetype)initWithName:(NSString *)name
{
    Class ownClass = self.class;
    Class baseClass = WEOperation.class;
    if (ownClass == baseClass) THROW_ABSTRACT(@{ NSLocalizedDescriptionKey: @"WEOperation is abstract and must be subclassed." });
    
    if (self = [super init])
    {
        pthread_mutex_init(&_mutex, NULL);
        _state = WEOperationInactive;
        _name = name;
    }
    return self;
}

- (void)dealloc
{
    if (_state == WEOperationActive) THROW_INCONSISTENCY(@{ NSLocalizedDescriptionKey: @"Active operation should not be deallocated" });
    
    pthread_mutex_destroy(&_mutex);
}

static inline BOOL
_IsOperationInState(__unsafe_unretained WEOperation *operation, WEOperationState state)
{
    BOOL result = NO;
    ENTER_CRITICAL_SECTION(operation, _mutex)
    result = operation->_state == state;
    LEAVE_CRITICAL_SECTION(operation, _mutex)
    return result;
}

- (BOOL)isActive
{
    return _IsOperationInState(self, WEOperationActive);
}

- (BOOL)isFinished
{
    return _IsOperationInState(self, WEOperationComplete);
}

- (BOOL)isCancelled
{
    return _IsOperationInState(self, WEOperationCancelled);
}

- (void)startWithCompletion:(void (^)(WEOperationResult * _Nullable))completion completionQueue:(dispatch_queue_t)completionQueue
{
    if ((completion != nil) ^ (completionQueue != nil)) THROW_INVALID_PARAMS(@{ NSLocalizedDescriptionKey: @"Either completion or completion queue is nil, but not both" });

    ENTER_CRITICAL_SECTION(self, _mutex)
    
    if (_state != WEOperationInactive) THROW_INCONSISTENCY(@{ NSLocalizedDescriptionKey: @"Operation cannot start because it is in an invalid state" });
    
    _state = WEOperationActive;
    _completion = completion;
    _completionQueue = completionQueue;
    
    LEAVE_CRITICAL_SECTION(self, _mutex)
    
    [self start];
}

- (void)completeWithResult:(WEOperationResult *)result
{
    if (result == nil) THROW_INVALID_PARAM(result, @{ NSLocalizedDescriptionKey: @"Result must be provided" });
    
    ENTER_CRITICAL_SECTION(self, _mutex)
    
    if (_state != WEOperationActive) THROW_INCONSISTENCY(@{ NSLocalizedDescriptionKey: @"Operation cannot be completed because it is in an invalid state" });
    
    _state = WEOperationComplete;

    LEAVE_CRITICAL_SECTION(self, _mutex)
}


#pragma mark - Overridables - defaults

- (BOOL)requiresMainThread
{
    THROW_ABSTRACT(nil);
}

- (void)prepareForExecutionWithContext:(__kindof WEWorkflowContext *)context
{
    // Default implementation does nothing
}

- (void)start
{
    THROW_ABSTRACT(nil);
}


@end
