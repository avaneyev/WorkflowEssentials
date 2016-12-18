//
//  WESegueDescription.h
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <Foundation/Foundation.h>

/**
 Describes a segue from one operation to another. A segue may be conditional.
 If a segue is defined from operation A to operation B, that means when operation A completes,
 segue condition will be evaluated, and if it passes operation B will start.
 Absence of a condition is equivalent to a condition that always passes.
 */
@interface WESegueDescription : NSObject

@end
