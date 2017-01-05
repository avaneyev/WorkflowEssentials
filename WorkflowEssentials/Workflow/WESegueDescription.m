//
//  WESegueDescription.m
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <WorkflowEssentials/WESegueDescription.h>

@implementation WESegueDescription

@synthesize condition = _condition;

- (id)copyWithZone:(NSZone *)zone
{
    WESegueDescription *copy = [super copyWithZone:zone];
    copy->_condition = [_condition copyWithZone:zone];
    return copy;
}

+ (nonnull WESegueDescription *)segueFromOperationName:(nonnull NSString *)from toOperationName:(nonnull NSString *)to condition:(nullable NSPredicate *)condition
{
    WESegueDescription *segue = [[WESegueDescription alloc] init];
    segue.sourceOperationName = from;
    segue.targetOperationName = to;
    segue.condition = condition;
    return segue;
}

@end
