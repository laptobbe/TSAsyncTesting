//
//  TSAsyncTestingTests.m
//  TSCoreData
//
//  Created by Tobias Sundstrand on 2014-03-06.
//  Copyright (c) 2014 Computertalk Sweden. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TSAsyncTesting.h"

@interface TSAsyncTestingTests : XCTestCase

@end

@implementation TSAsyncTestingTests

- (void)setUp {
    [super setUp];
    [TSAsyncTesting initialize];
}

- (void)tearDown {
    [TSAsyncTesting initialize];
    [super tearDown];
}

- (void)testPerformOnBackgroundThread {
    __block BOOL hasRun = NO;
    [TSAsyncTesting testOnBackgroundQueue:^{
        hasRun = YES;
    }];
    XCTAssertTrue(hasRun);
}

- (void)testOnBackgroundThreadTimeOut {
    __block BOOL hasRun = NO;
    XCTAssertThrowsSpecificNamed([TSAsyncTesting testOnBackgroundQueueTimeOut:1 action:^{
        [TSAsyncTesting blockThread];
        hasRun = YES;
    }], NSException, TSTestTimeoutException);

    XCTAssertFalse(hasRun);
}

- (void)testOnOwnQueue {
    __block BOOL hasRun = NO;
    dispatch_queue_t queue = dispatch_queue_create("Test queue", DISPATCH_QUEUE_SERIAL);
    [TSAsyncTesting testWithTimeOut:2
                            onQueue:queue
                             action:^{
                                 hasRun = YES;
                             }
                         signalWhen:^BOOL {
                             return YES;
                         }];
    XCTAssertTrue(hasRun);
}

- (void)testBasicWaitAndSignal {
    __block BOOL hasRun = NO;
    dispatch_queue_t queue = dispatch_queue_create("Test queue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(queue, ^{
        hasRun = YES;
        [TSAsyncTesting signal];
    });
    [TSAsyncTesting wait];
    XCTAssertTrue(hasRun);
}

- (void)testBasicTimeout {
    __block BOOL hasRun = NO;
    dispatch_queue_t queue = dispatch_queue_create("Test queue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(queue, ^{
        [TSAsyncTesting blockThread];
        hasRun = YES;
        [TSAsyncTesting signal];
    });
    XCTAssertThrowsSpecificNamed([TSAsyncTesting waitWithTimeOut:1], NSException, TSTestTimeoutException);
    XCTAssertFalse(hasRun);
}

- (void)testSignalWhen {
    NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
        for (int j = 0; j < 1000; j++);
    }];

    XCTAssertFalse(blockOperation.isFinished);

    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [queue addOperation:blockOperation];

    [TSAsyncTesting signalWhen:^{
        return blockOperation.isFinished;
    }];

    [TSAsyncTesting wait];
    XCTAssertTrue(blockOperation.isFinished);
}

- (void)testSignalThrowsInternalInconsistencyErrorIfNoWait {
    XCTAssertThrowsSpecificNamed([TSAsyncTesting signal], NSException, NSInternalInconsistencyException);
}

- (void)testOnBackgroundQueueCustomSignaling {
    __block long count = 0;
    dispatch_queue_t queue = dispatch_queue_create("Test queue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(queue, ^{
        while (count < 10000000000000000) {
            count++;
        }
    });

    [TSAsyncTesting testOnBackgroundQueueTimeOut:10
                                          action:^{
                                              //Some action then start waiting for external state change
                                          }
                                      signalWhen:^BOOL {
                                          return count > 100000000;
                                      }];
    XCTAssertTrue(count > 100000000);
}

- (void)testCallbackOnMainQueue {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [TSAsyncTesting signal];
        });
    });

    [TSAsyncTesting waitWithTimeOut:2];
}

- (void)testCallbackOnBackgroundQueue {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [TSAsyncTesting signal];
        });
    });
    [TSAsyncTesting waitWithTimeOut:2];
}

- (void)testCallbackWithDispatchSyncOnMain {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        dispatch_sync(dispatch_get_main_queue(), ^{
            [TSAsyncTesting signal];
        });
    });
    [TSAsyncTesting waitWithTimeOut:2];
}

- (void)testWithDispatchThread {
    [NSThread detachNewThreadSelector:@selector(backgroundMethod) toTarget:self withObject:nil];
    [TSAsyncTesting waitWithTimeOut:2];
}

- (void)backgroundMethod {
    sleep(1);
    [TSAsyncTesting signal];
}

@end
