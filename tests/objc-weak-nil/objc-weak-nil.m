#import <Foundation/Foundation.h>
#include <stdio.h>

int main(void)
{
    @autoreleasepool
    {
        NSObject *strong = [NSObject new];
        __weak NSObject *weak = strong;
        int checks = weak == strong;
        strong = nil;
        checks += weak == nil;
        printf("objc-weak-nil: %d/2\n", checks);
        return checks == 2 ? 0 : 1;
    }
}
