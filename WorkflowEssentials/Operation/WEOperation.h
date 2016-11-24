//
//  WEOperation.h
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <Foundation/Foundation.h>

@class WEOperationResult;

@interface WEOperation : NSObject

- (nonnull instancetype)initWithName:(nullable NSString *)name NS_DESIGNATED_INITIALIZER;

// Optional operation name that can be used by other operations to its result or
// the operation itself as a dependency.
@property (nonatomic, readonly, retain, nullable) NSString *name;

@property (nonatomic, readonly) BOOL requiresMainThread;

/**
 Called when the workflow is ready to start an operation, but before the start.
 Allows an operation to to prepare itself for execution.
 This gives an operation a chance to check its prerequisites and schedule additional work to be done 
 before the operation is performed
 */
- (void)prepareForExecution;

/**
 Starts the operation
 @param completion completion block that needs to be invoked when the operation completes
 */
- (void)startWithCompletion:(nonnull void (^)(WEOperationResult * _Nullable result))completion;

@end
