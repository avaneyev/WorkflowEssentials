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

- (nonnull instancetype)initWithResult:(nullable id<NSCopying>)result;
- (nonnull instancetype)initWithError:(nonnull NSError *)error;

@property (nonatomic, readonly, getter=isFailed) BOOL failed;
@property (nonatomic, readonly, copy, nullable) id<NSCopying> result;
@property (nonatomic, readonly, strong, nullable) NSError *error;

@end
