#include <stdio.h>
#include <objc/runtime.h>

static int constructed;
static int destructed;
struct Counter { Counter() { ++constructed; } ~Counter() { ++destructed; } int value = 40; };

__attribute__((objc_root_class))
@interface CxxObject
{ Class isa; Counter counter; }
+ (id)new;
- (int)value;
@end
@implementation CxxObject
+ (id)new { return class_createInstance(self, 0); }
- (int)value { return counter.value + 2; }
@end

int main(void)
{
    id object = [CxxObject new];
    int value = [object value];
    object_dispose(object);
    printf("objcxx-ivars: %d\n", value);
    return value == 42 && constructed == 1 && destructed == 1 ? 0 : 1;
}
