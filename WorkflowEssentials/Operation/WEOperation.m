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
#import "WETools.h"

@implementation WEOperation
{
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
        _name = name;
    }
    return self;
}

- (BOOL)requiresMainThread
{
    THROW_ABSTRACT(nil);
}

- (void)prepareForExecution
{
    // Default implementation does nothing
}

- (void)startWithCompletion:(void (^)(WEOperationResult * _Nullable))completion
{
    THROW_ABSTRACT(nil);
}

@end
