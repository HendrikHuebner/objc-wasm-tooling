#import <Foundation/Foundation.h>
#include <stdio.h>

@interface NotificationObserver : NSObject
@property int notifications;
@end

@implementation NotificationObserver
@synthesize notifications;
- (void)received:(NSNotification *)notification
{
    if ([notification.name isEqualToString:@"objc-wasm-test"] &&
        [[[notification.userInfo objectForKey:@"answer"] description] isEqualToString:@"42"])
        self.notifications++;
}
@end

int main(void)
{
    @autoreleasepool
    {
        int checks = 0;

        NSString *value = [NSString stringWithFormat:@"%@ %d", @"answer", 42];
        NSRange range = [value rangeOfString:@"42"];
        checks += [value hasPrefix:@"answer"] && range.location == 7 && range.length == 2;
        checks += [[value dataUsingEncoding:NSUTF8StringEncoding] length] == 9;

        NSArray *array = @[@"objc", @"wasm", @"runtime"];
        NSDictionary *dictionary = @{ @"answer": @42, @"items": array };
        NSSet *set = [NSSet setWithArray:array];
        checks += [array count] == 3 && [set count] == 3;
        checks += [[dictionary objectForKey:@"answer"] intValue] == 42;
        checks += [[[dictionary objectForKey:@"items"] objectAtIndex:2]
                   isEqualToString:@"runtime"];

        const unsigned char bytes[] = { 4, 2, 0, 8 };
        NSMutableData *data = [NSMutableData dataWithBytes:bytes length:sizeof(bytes)];
        ((unsigned char *)[data mutableBytes])[0] = 42;
        NSData *slice = [data subdataWithRange:NSMakeRange(0, 2)];
        checks += [data length] == sizeof(bytes) && ((unsigned char *)[slice bytes])[0] == 42;

        NSRange expectedRange = NSMakeRange(4, 2);
        NSValue *boxedRange = [NSValue valueWithRange:expectedRange];
        NSRange recoveredRange = NSMakeRange(0, 0);
        [boxedRange getValue:&recoveredRange];
        checks += NSEqualRanges(expectedRange, recoveredRange);

        NotificationObserver *observer = [NotificationObserver new];
        NSNotification *notification =
            [NSNotification notificationWithName:@"objc-wasm-test" object:nil
                                        userInfo:@{ @"answer": @42 }];
        checks += [notification.name isEqualToString:@"objc-wasm-test"] &&
                  [[notification.userInfo objectForKey:@"answer"] intValue] == 42;
        [observer received:notification];
        checks += observer.notifications == 1;

        printf("base-integration: %d/%d\n", checks, 9);
        return checks == 9 ? 0 : 1;
    }
}
