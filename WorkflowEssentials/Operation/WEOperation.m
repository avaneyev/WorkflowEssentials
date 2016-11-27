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
}

@synthesize name = _name;

- (instancetype)init
{
    return [self initWithName:nil];
}

- (instancetype)initWithName:(NSString *)name
{
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

- (BOOL)requiresMainThread
{
    THROW_ABSTRACT(nil);
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

- (void)prepareForExecutionWithContext:(__kindof WEWorkflowContext *)context
{
    // Default implementation does nothing
}

- (void)startWithCompletion:(void (^)(WEOperationResult * _Nullable))completion
{
    THROW_ABSTRACT(nil);
}

@end
