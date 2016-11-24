//
//  WETools.h
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#ifndef WorkflowEssentials_WETools_h
#define WorkflowEssentials_WETools_h

#ifdef DEBUG
#   define WELog(fmt, ...) NSLog((@"%s |%d| " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#   define WELog(...)
#endif

#define THROW_ABSTRACT(info) @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%s is abstract!",  __PRETTY_FUNCTION__] userInfo:(info)]
#define THROW_INCONSISTENCY(info) @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Inconsistency in %s!",  __PRETTY_FUNCTION__] userInfo:(info)]
#define THROW_NOT_IMPLEMENTED(info) @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%s is not implemented!",  __PRETTY_FUNCTION__] userInfo:(info)]
#define THROW_INVALID_PARAMS(info) @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"%s received invalid parameters!",  __PRETTY_FUNCTION__] userInfo:(info)]
#define THROW_INVALID_PARAM(param, info) @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"%s received invalid %s",  __PRETTY_FUNCTION__, #param] userInfo:(info)]

#endif
