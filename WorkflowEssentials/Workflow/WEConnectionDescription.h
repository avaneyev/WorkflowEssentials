//
//  WEConnectionDescription.h
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
 Describes a directional connection between two operations - source and target.
 Both source and target operations must be defined.
 Both can be defined by either specifying an operation object or providing an operation name,
 which will then be resolved to an operation.
 If a name was specified and resolving it to an operation fails (workflow does not have an operation
 with such name) an exception will be thrown. Name resolution will be performed when the workflow starts.
 Referencing operations by name rather than operation objects may be useful for loosely coupled
 workflow construction.
 */
@interface WEConnectionDescription : NSObject<NSCopying>

/**
 Source operation - an operation from which a connection is made.
 Source operation will have to complete for the connection to take effect.
 */
@property (nonatomic, strong, nullable) WEOperation *sourceOperation;

/**
 Source operation name - a name of the source operation.
 Operation names can be used instead of operations when an operation object is not known, 
 but it has a name and its name is known.
 If both source operation and source name are specified, name is ignored.
 */
@property (nonatomic, copy, nullable) NSString *sourceOperationName;

/**
 Target operation - an operation to which a connection is made.
 Target operation start will be dependent (in a way that connection defines) on source operation completion.
 */
@property (nonatomic, strong, nullable) WEOperation *targetOperation;

/**
 Target operation name - a name of the target operation
 Operation names can be used instead of operations when an operation object is not known,
 but it has a name and its name is known.
 If both target operation and target name are specified, name is ignored.
 */
@property (nonatomic, copy, nullable) NSString *targetOperationName;

@end
