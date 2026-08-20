#import <Foundation/Foundation.h>
#include <stdio.h>

extern char **environ;

@interface ThreadTarget : NSObject
{
    volatile int *_completed;
}
- (instancetype)initWithCompleted:(volatile int *)completed;
- (void)run:(id)object;
@end

@implementation ThreadTarget
- (instancetype)initWithCompleted:(volatile int *)completed
{
    self = [super init];
    if (self != nil)
        _completed = completed;
    return self;
}

- (void)run:(id)object
{
    (void)object;
    *_completed = 42;
}
@end

int main(int argc, char **argv)
{
    [NSProcessInfo initializeWithArguments:argv count:argc environment:environ];
    @autoreleasepool
    {
        NSThread *current = [NSThread currentThread];
        NSThread *main = [NSThread mainThread];
        int checks = current != nil && current == main;
        checks += [NSThread isMainThread] && [current isMainThread];
        checks += ![NSThread isMultiThreaded];

        NSMutableDictionary *dictionary = [current threadDictionary];
        [dictionary setObject:@42 forKey:@"answer"];
        checks += [[dictionary objectForKey:@"answer"] intValue] == 42;

        volatile int completed = 0;
        ThreadTarget *target = [[ThreadTarget alloc] initWithCompleted:&completed];
        NSThread *thread = [[NSThread alloc] initWithTarget:target
                                                   selector:@selector(run:)
                                                     object:nil];
        [thread setName:@"objc-wasm-test"];
        checks += ![thread isExecuting] && ![thread isFinished] &&
                  ![thread isCancelled];
        checks += [[thread name] isEqualToString:@"objc-wasm-test"];
        [thread start];
        checks += completed == 42;
        checks += [thread isFinished] && ![thread isExecuting];
        [thread cancel];
        checks += [thread isCancelled];

        printf("base-nsthread: %d/9\n", checks);
        return checks == 9 ? 0 : 1;
    }
}
