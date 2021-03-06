//
//  WEBlockOperation.h
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <WorkflowEssentials/WEOperation.h>

@interface WEBlockOperation<__covariant WEResultType : id<NSCopying> > : WEOperation<WEResultType>

- (nullable instancetype)init NS_UNAVAILABLE;
- (nonnull instancetype)initWithName:(nullable NSString *)name NS_UNAVAILABLE;

- (nonnull instancetype)initWithName:(nullable NSString *)name requiresMainThread:(BOOL)requiresMain block:(nonnull void (^)(void  (^ _Nonnull completion)(WEOperationResult<WEResultType> * _Nonnull result)))block;

@end
