//
//  WEWorkflow.h
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <Foundation/Foundation.h>

@class WEWorkflowContext;
@class WEOperation;

@interface WEWorkflow : NSObject

- (nonnull instancetype)initWithContextClass:(nullable Class)contextClass
                 maximumConcurrentOperations:(NSUInteger)maximumConcurrentOperations;

@property (nonatomic, readonly, getter=isActive) BOOL active;

@property (nonatomic, readonly, strong, nonnull) WEWorkflowContext *context;

@property (nonatomic, readonly, nonnull) NSArray<WEOperation *> *operations;
@property (nonatomic, readonly) NSUInteger operationCount;

@end
