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

@implementation WEWorkflow
{
    WEWorkflowContext *_context;
    NSUInteger _maximumConcurrentOperations;
    
    pthread_mutex_t _operationMutex;
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
        _operationsReadyToExecute = [NSMutableOrderedSet new];
    }
    return self;
}

- (void)dealloc
{
    pthread_mutex_destroy(&_operationMutex);
}


#pragma mark - Properties

@synthesize context = _context;

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

@end
