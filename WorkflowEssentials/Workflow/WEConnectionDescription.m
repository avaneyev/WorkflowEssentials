//
//  WEConnectionDescription.m
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import "WEConnectionDescription.h"

@implementation WEConnectionDescription

@synthesize sourceOperation = _sourceOperation,
    sourceOperationName = _sourceOperationName,
    targetOperation = _targetOperation,
    targetOperationName = _targetOperationName;

- (id)copyWithZone:(NSZone *)zone
{
    WEConnectionDescription *copy = [[[self class] allocWithZone:zone] init];
    copy->_sourceOperation = _sourceOperation;
    copy->_sourceOperationName = [_sourceOperationName copyWithZone:zone];
    copy->_targetOperation = _targetOperation;
    copy->_targetOperationName = [_targetOperationName copyWithZone:zone];
    return copy;
}

@end
