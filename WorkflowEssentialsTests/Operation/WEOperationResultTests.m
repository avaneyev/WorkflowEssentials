//
//  WEOperationResultTests.m
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <XCTest/XCTest.h>
#import <WorkflowEssentials/WEOperationResult.h>

#import <XCTest/XCTest.h>

@interface FancyCopier : NSObject<NSCopying>
@property (nonatomic, readonly, nonnull) NSString *string;
@end

@implementation FancyCopier

- (instancetype)initWithString:(NSString *)string
{
    if (self = [super init]) {
        _string = [string copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    FancyCopier *copy = [[FancyCopier alloc] initWithString:[_string stringByAppendingString:@"-copy"]];
    return copy;
}

@end

@interface WEOperationResultTests : XCTestCase
@end

@implementation WEOperationResultTests

- (void)testSuccessfulResultNoValue
{
    WEOperationResult *result = [[WEOperationResult alloc] initWithResult:nil];
    
    XCTAssertFalse(result.isFailed);
    XCTAssertNil(result.result);
    XCTAssertNil(result.error);
}

- (void)testSuccessResultCopiesValue
{
    FancyCopier *resultData = [[FancyCopier alloc] initWithString:@"result"];
    WEOperationResult<FancyCopier *> *result = [[WEOperationResult alloc] initWithResult:resultData];
    XCTAssertFalse(result.isFailed);
    FancyCopier *returnedData = result.result;
    XCTAssertNotNil(returnedData);
    XCTAssertNil(result.error);
    
    XCTAssertNotEqual(returnedData, resultData);
    XCTAssertEqualObjects(result.result, returnedData);
    XCTAssertEqualObjects(returnedData.string, @"result-copy");
}

-(void)testFailingResultWithError
{
    NSError *error = [NSError errorWithDomain:@"ArbitraryDomain" code:-12345 userInfo:nil];
    WEOperationResult<FancyCopier *> *result = [[WEOperationResult alloc] initWithError:error];
    
    XCTAssertTrue(result.isFailed);
    XCTAssertEqual(result.error, error);
}

- (WEOperationResult *)_helperCreateFailureResultWithError:(NSError *)error
{
    return [[WEOperationResult alloc] initWithError:error];
}

- (void)testFailingResultThrowsWithNilError
{
    XCTAssertThrows([self _helperCreateFailureResultWithError:nil]);
}

@end
