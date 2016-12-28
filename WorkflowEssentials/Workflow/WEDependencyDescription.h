//
//  WEDependencyDescription.h
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <WorkflowEssentials/WEConnectionDescription.h>

/**
 Dependency is a type of connection that requires source operation to complete before target can start.
 If a target operation has multiple dependency connections, all of their sources will have to complete
 before the target operation starts.
 Dependency operation is unconditional and does not have any parameters.
 */
@interface WEDependencyDescription : WEConnectionDescription

+ (nonnull WEDependencyDescription *)dependencyFormOperation:(nonnull WEOperation *)from toOperation:(nonnull WEOperation *)to;
+ (nonnull WEDependencyDescription *)dependencyFormOperationName:(nonnull NSString *)from toOperationName:(nonnull NSString *)to;

@end
