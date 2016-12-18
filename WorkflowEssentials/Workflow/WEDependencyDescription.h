//
//  WEDependencyDescription.h
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <Foundation/Foundation.h>

@class WEOperation;

/**
 Describes a dependency between a dependent operation and a source.
 Dependent operation will wait for all of its dependency sources to complete before starting.
 Both source and dependent operations must be defined. 
 Both can be defined by either specifying an operation object or providing an operation name,
 which will then be resolved to an operation.
 If a name was specified and resolving it to an operation fails (workflow does not have an operation
 with such name) an exception will be thrown.
 */
@interface WEDependencyDescription : NSObject<NSCopying>

/**
 Dependency source operation - an operation that will have to complete before dependent operation starts.
 */
@property (nonatomic, strong, nullable) WEOperation *sourceOperation;

/**
 Dependency source name - a name of an operation that will have to complete before dependent operation starts.
 */
@property (nonatomic, copy, nullable) NSString *sourceOperationName;

/**
 Dependent operation - an operation that will have to wait before all its dependencies complete.
 */
@property (nonatomic, strong, nullable) WEOperation *dependentOperation;

/**
 Dependent operation name - a name of an operation that will have to wait before all its dependencies complete.
 */
@property (nonatomic, copy, nullable) NSString *dependentOperationName;

@end
