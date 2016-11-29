//
//  WEOperationResult.m
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <WorkflowEssentials/WEOperationResult.h>
#import "WETools.h"

@implementation WEOperationResult
{
    id<NSCopying> _result;
    NSError *_error;
}

- (instancetype)init
{
    return [self initWithResult:nil];
}

- (instancetype)initWithResult:(id<NSCopying>)result
{
    if (self = [super init])
    {
        _result = [result copyWithZone:nil];
    }
    return self;
}

- (instancetype)initWithError:(NSError *)error
{
    if (error == nil) THROW_INVALID_PARAM(error, nil);
    
    if (self = [super init])
    {
        _error = error;
    }
    return self;
}

@synthesize result = _result;
@synthesize error  = _error;

- (BOOL)isFailed
{
    return _error != nil;
}

@end
