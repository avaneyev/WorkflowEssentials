//
//  WEWorkflowContext.h
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <Foundation/Foundation.h>

@class WEWorkflow;
@class WEOperationResult;

@interface WEWorkflowContext : NSObject

- (nullable instancetype)init NS_UNAVAILABLE;
- (nonnull instancetype)initWithWorkflow:(nonnull WEWorkflow *)workflow NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly, weak, nullable) WEWorkflow *workflow;

- (nullable WEOperationResult *)resultForOperationName:(nonnull NSString *)name;

- (nullable id)contextValueForKey:(nonnull id<NSCopying>)key;
- (void)setContextValue:(nonnull id)value forKey:(nonnull id<NSCopying>)key;
- (void)removeContextValueForKey:(nonnull id<NSCopying>)key;

@end
