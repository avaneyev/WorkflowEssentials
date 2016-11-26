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
#import "WETools.h"

@implementation WEWorkflow
{
    WEWorkflowContext *_context;
    NSUInteger _maximumConcurrentOperations;
}

@synthesize context = _context;

- (instancetype)init
{
    return [self initWithContextClass:nil maximumConcurrentOperations:0];
}

- (instancetype)initWithContextClass:(Class)contextClass
         maximumConcurrentOperations:(NSUInteger)maximumConcurrentOperations
{
    if (contextClass != nil && ![contextClass isSubclassOfClass:[WEWorkflowContext class]])
    {
        THROW_INVALID_PARAM(contextClass, nil);
    }
    
    if (self = [super init])
    {
        if (contextClass == nil) contextClass = [WEWorkflowContext class];
        _context = [[contextClass alloc] init];
        
        _maximumConcurrentOperations = (maximumConcurrentOperations > 0) ? maximumConcurrentOperations : INT32_MAX;
    }
    return self;
}

@end
