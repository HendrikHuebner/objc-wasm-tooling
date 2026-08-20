#include <stdio.h>
#include <objc/runtime.h>

__attribute__((objc_root_class))
@interface ArcObject
+ (int)marker;
@end
@implementation ArcObject
+ (int)marker { return 1; }
@end

int main(void)
{
    __strong id strong = nil;
    strong = nil;
    int ok = [ArcObject marker] == 1 && strong == nil;
    printf("objc-arc: %d\n", ok ? 42 : 0);
    return ok ? 0 : 1;
}
