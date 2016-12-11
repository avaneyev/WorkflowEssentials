//
//  WEBlockOperation.m
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <WorkflowEssentials/WEBlockOperation.h>
#import "WETools.h"

@implementation WEBlockOperation
{
    BOOL _requiresMainThread;
    void (^_block)(void (^ _Nonnull)(WEOperationResult * _Nonnull));
}

- (instancetype)initWithName:(NSString *)name requiresMainThread:(BOOL)requiresMain block:(nonnull void (^)(void (^ _Nonnull)(WEOperationResult * _Nonnull)))block
{
    if (block == nil) THROW_INVALID_PARAM(block, nil);
    
    if (self = [super initWithName:name])
    {
        _requiresMainThread = requiresMain;
        _block = block;
    }
    return self;
}

- (BOOL)requiresMainThread
{
    return _requiresMainThread;
}

- (void)start
{
    WEAssert(_requiresMainThread == [NSThread isMainThread]);
    
    void (^completion)(WEOperationResult *) = ^(WEOperationResult *result) {
        [self completeWithResult:result];
    };
    
    _block(completion);
}

@end
