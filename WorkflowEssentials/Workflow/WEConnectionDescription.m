//
//  WEConnectionDescription.m
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <WorkflowEssentials/WEConnectionDescription.h>

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

static NSString *_DescriptionForOperationOrName(WEOperation *operation, NSString *name)
{
    if (operation != nil) return [NSString stringWithFormat:@"%@", operation];
    return [NSString stringWithFormat:@"(named = %@)", name];
}

- (NSString *)description
{
    NSMutableString *result = [[NSMutableString alloc] initWithFormat:@"<%@(%p), from = %@, to = %@>",
                               NSStringFromClass([self class]),
                               self,
                               _DescriptionForOperationOrName(_sourceOperation, _sourceOperationName),
                               _DescriptionForOperationOrName(_targetOperation, _targetOperationName)
                               ];
    
    
    return result;
}

@end
