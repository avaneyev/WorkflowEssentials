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

@class WEOperationResult;

@interface WEWorkflowContext : NSObject

- (nullable WEOperationResult *)resultForOperationName:(nonnull NSString *)name;

- (nullable id)contextValueForKey:(nonnull id<NSCopying>)key;
- (void)setContextValue:(nonnull id)value forKey:(nonnull id<NSCopying>)key;
- (void)removeContextValueForKey:(nonnull id<NSCopying>)key;

@end
