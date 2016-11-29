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

- (void)dealloc
{
    pthread_mutex_destroy(&_contextMutex);
}

- (WEOperationResult *)resultForOperationName:(NSString *)name
{
    if (name == nil) THROW_INVALID_PARAM(name, nil);
    WEOperationResult *result;
    
    ENTER_CRITICAL_SECTION(self, _contextMutex)
        result = _results[name];
    LEAVE_CRITICAL_SECTION(self, _contextMutex)

    return result;
}

- (id)contextValueForKey:(id<NSCopying>)key
{
    if (key == nil) THROW_INVALID_PARAM(key, nil);

    id result;
    ENTER_CRITICAL_SECTION(self, _contextMutex)
        result = _userContext[key];
    LEAVE_CRITICAL_SECTION(self, _contextMutex)
    return result;
}

- (void)setContextValue:(id)value forKey:(id<NSCopying>)key
{
    if (key == nil) THROW_INVALID_PARAM(key, nil);
    if (value == nil) THROW_INVALID_PARAM(value, nil);

    ENTER_CRITICAL_SECTION(self, _contextMutex)
        if (_userContext == nil) _userContext = [NSMutableDictionary new];
        _userContext[key] = value;
    LEAVE_CRITICAL_SECTION(self, _contextMutex)
}

- (void)removeContextValueForKey:(id<NSCopying>)key
{
    if (key == nil) THROW_INVALID_PARAM(key, nil);
    
    ENTER_CRITICAL_SECTION(self, _contextMutex)
        [_userContext removeObjectForKey:key];
    LEAVE_CRITICAL_SECTION(self, _contextMutex)
}

@end
