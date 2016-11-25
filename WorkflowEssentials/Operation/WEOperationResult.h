//
//  WEOperationResult.h
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <Foundation/Foundation.h>

@interface WEOperationResult : NSObject

/**
 Initializes an operation result object as successfully completed with optional result data.
 @param result optional result value of an operation.
 */
- (nonnull instancetype)initWithResult:(nullable id<NSCopying>)result;
/**
 Initializes an operation result object as failed with error.
 @param error an error object representing the failure (required).
 */
- (nonnull instancetype)initWithError:(nonnull NSError *)error;

/** Returns YES if the operation failed, and NO otherwise */
@property (nonatomic, readonly, getter=isFailed) BOOL failed;
/** Returns the result object (optional, only when provided for successfully completed operations) */
@property (nonatomic, readonly, copy, nullable) id<NSCopying> result;
/** Returns an error for a failed operation */
@property (nonatomic, readonly, strong, nullable) NSError *error;

@end
