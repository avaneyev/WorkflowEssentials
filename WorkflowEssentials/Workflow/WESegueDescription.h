//
//  WESegueDescription.h
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <WorkflowEssentials/WEConnectionDescription.h>

/**
 Describes a segue from one operation to another. A segue may be conditional.
 If a segue is defined from operation A to operation B, that means when operation A completes,
 segue condition will be evaluated, and if it passes operation B will start.
 Absence of a condition is equivalent to a condition that always passes.
 */
@interface WESegueDescription : WEConnectionDescription

/**
 Segue condition predicate.
 Condition will be evaluated with source operation result.
 If the condition is YES, target operation will execute.
 */
@property (nonatomic, strong, nullable) NSPredicate *condition;

@end
