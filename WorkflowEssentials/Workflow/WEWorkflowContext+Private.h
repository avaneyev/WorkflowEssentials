//
//  WEWorkflowContext+Private.h
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <WorkflowEssentials/WEWorkflowContext.h>

@interface WEWorkflowContext ()
- (void)_setOperationResult:(nonnull WEOperationResult *)result forOperationName:(nonnull NSString *)operationName;
@end
