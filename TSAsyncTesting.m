//
// Created by Tobias Sundstrand on 2014-03-05.
// Copyright (c) 2014 Computertalk Sweden. All rights reserved.
//

#import "TSAsyncTesting.h"

NSString *const TSTestTimeoutException = @"TSTestTimoutException";

static NSUInteger threadCount = 0;
static dispatch_semaphore_t semaphore = nil;
#define SUFFICIENT_LONG_WAIT (60 * 60 * 24)

@implementation TSAsyncTesting

+ (void)testOnBackgroundQueue:(TSAsyncActionBlock)block {
    [self testOnBackgroundQueueTimeOut:SUFFICIENT_LONG_WAIT action:block];
}

+ (void)testOnBackgroundQueueTimeOut:(NSTimeInterval)time action:(TSAsyncActionBlock)action {
    [self testOnBackgroundQueueTimeOut:time action:action signalWhen:^BOOL {
        return YES;
    }];
}

+ (void)testOnBackgroundQueueTimeOut:(NSTimeInterval)time action:(TSAsyncActionBlock)action signalWhen:(TSAsyncWhenBlock)when {
    dispatch_queue_t backgroundQueue = [self createBackgroundQueue];
    [self testWithTimeOut:time onQueue:backgroundQueue action:action signalWhen:when];
}

+ (dispatch_queue_t)createBackgroundQueue {
    return dispatch_queue_create("Test background thread", DISPATCH_QUEUE_SERIAL);
}

+ (void)testWithTimeOut:(NSTimeInterval)time onQueue:(dispatch_queue_t)queue action:(TSAsyncActionBlock)action signalWhen:(TSAsyncWhenBlock)when {

    dispatch_async(queue, ^{
        [[NSThread currentThread] setName:[NSString stringWithFormat:@"TSAsyncTesting thread %d", ++threadCount]];
        action();
        [self signalWhen:when];
    });
    [self waitWithTimeOut:time];
}

+ (void)wait {
    [self waitWithTimeOut:SUFFICIENT_LONG_WAIT];
}

+ (void)initialize {
    semaphore = nil;
}

+ (void)waitWithTimeOut:(NSTimeInterval)timeOut {
    semaphore = dispatch_semaphore_create(0);
    long result = dispatch_semaphore_wait(semaphore, [self dispatchTimeFromTimeInterval:timeOut]);
    semaphore = nil;
    if (result != 0) {
        [NSException raise:TSTestTimeoutException format:@"TSAsyncTesting timed out waiting, waited for: %.1f seconds", timeOut];
    }
}

+ (dispatch_time_t)dispatchTimeFromTimeInterval:(NSTimeInterval)timeInterval {
    return dispatch_time(DISPATCH_TIME_NOW, (int64_t) (timeInterval * NSEC_PER_SEC));
}

+ (void)blockThread {
    for(;;);
}

+ (void)signalWhen:(TSAsyncWhenBlock)block {
    dispatch_async([self createBackgroundQueue], ^{
        while (!block());
        [TSAsyncTesting signal];
    });
}

+ (void)signal {
    if (!semaphore) {
        [NSException raise:NSInternalInconsistencyException format:@"No waiting action"];
    }
    dispatch_semaphore_signal(semaphore);
}

@end