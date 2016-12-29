//
//  WEDependencyDescription.m
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <WorkflowEssentials/WEDependencyDescription.h>

@implementation WEDependencyDescription

+ (WEDependencyDescription *)dependencyFormOperation:(WEOperation *)from toOperation:(WEOperation *)to
{
    WEDependencyDescription *dependency = [[WEDependencyDescription alloc] init];
    dependency.sourceOperation = from;
    dependency.targetOperation = to;
    return dependency;
}

+ (nonnull WEDependencyDescription *)dependencyFormOperationName:(nonnull NSString *)from toOperationName:(nonnull NSString *)to
{
    WEDependencyDescription *dependency = [[WEDependencyDescription alloc] init];
    dependency.sourceOperationName = from;
    dependency.targetOperationName = to;
    return dependency;
}

@end
