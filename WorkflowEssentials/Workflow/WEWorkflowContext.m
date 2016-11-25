//
//  WEWorkflowContext.m
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <WorkflowEssentials/WEWorkflowContext.h>

#include <pthread.h>
#import "WETools.h"

// Pair of macros to enter and leave the critical section
#define ENTER_CRITICAL_SECTION(context)           \
@try                                              \
{                                                 \
pthread_mutex_lock(&(context->_contextMutex));

#define LEAVE_CRITICAL_SECTION(context)             \
}                                                   \
@finally                                            \
{                                                   \
pthread_mutex_unlock(&(context->_contextMutex));    \
}


@implementation WEWorkflowContext
{
    pthread_mutex_t _contextMutex;
    NSMutableDictionary<NSString *, WEOperationResult *> *_results;
    NSMutableDictionary<id<NSCopying>, id> *_userContext;
}

- (instancetype)init
{
    if (self = [super init])
    {
        pthread_mutex_init(&_contextMutex, NULL);
        _results = [NSMutableDictionary new];
    }
    return self;
}

- (WEOperationResult *)resultForOperationName:(NSString *)name
{
    if (name == nil) THROW_INVALID_PARAM(name, nil);
    WEOperationResult *result;
    
    ENTER_CRITICAL_SECTION(self)
        result = _results[name];
    LEAVE_CRITICAL_SECTION(self);

    return result;
}

- (id)contextValueForKey:(id<NSCopying>)key
{
    if (key == nil) THROW_INVALID_PARAM(key, nil);

    id result;
    ENTER_CRITICAL_SECTION(self)
        result = _userContext[key];
    LEAVE_CRITICAL_SECTION(self);
    return result;
}

- (void)setContextValue:(id)value forKey:(id<NSCopying>)key
{
    if (key == nil) THROW_INVALID_PARAM(key, nil);
    if (value == nil) THROW_INVALID_PARAM(value, nil);

    ENTER_CRITICAL_SECTION(self)
        if (_userContext == nil) _userContext = [NSMutableDictionary new];
        _userContext[key] = value;
    LEAVE_CRITICAL_SECTION(self);
}

- (void)removeContextValueForKey:(id<NSCopying>)key
{
    if (key == nil) THROW_INVALID_PARAM(key, nil);
    
    ENTER_CRITICAL_SECTION(self)
        [_userContext removeObjectForKey:key];
    LEAVE_CRITICAL_SECTION(self);
}

@end
