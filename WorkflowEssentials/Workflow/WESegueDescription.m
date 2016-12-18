//
//  WESegueDescription.m
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import "WESegueDescription.h"

@implementation WESegueDescription

@synthesize condition = _condition;

- (id)copyWithZone:(NSZone *)zone
{
    WESegueDescription *copy = [super copyWithZone:zone];
    copy->_condition = [_condition copyWithZone:zone];
    return copy;
}

@end
