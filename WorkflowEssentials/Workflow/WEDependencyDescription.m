//
//  WEDependencyDescription.m
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import "WEDependencyDescription.h"

@implementation WEDependencyDescription

@synthesize sourceOperation = _sourceOperation,
    sourceOperationName = _sourceOperationName,
    dependentOperation = _dependentOperation,
    dependentOperationName = _dependentOperationName;

- (id)copyWithZone:(NSZone *)zone
{
    WEDependencyDescription *copy = [[WEDependencyDescription allocWithZone:zone] init];
    copy->_dependentOperation = _dependentOperation;
    copy->_dependentOperationName = [_dependentOperationName copyWithZone:zone];
    copy->_sourceOperation = _sourceOperation;
    copy->_dependentOperationName = [_sourceOperationName copyWithZone:zone];
    return copy;
}

@end
