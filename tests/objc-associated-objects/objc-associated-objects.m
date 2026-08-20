#include <stdio.h>
#include <objc/runtime.h>

static char key;

__attribute__((objc_root_class))
@interface AssociationObject
{
    Class isa;
}
+ (id)new;
- (id)retain;
- (oneway void)release;
@end

@implementation AssociationObject
+ (id)new { return class_createInstance(self, 0); }
- (id)retain { return self; }
- (oneway void)release {}
@end

@interface AssociationValue : AssociationObject @end
@implementation AssociationValue @end

int main(void)
{
    id object = [AssociationObject new];
    id value = [AssociationValue new];
    // The assign policy isolates association storage from retain/release ABI
    // details, which are tested separately by the ownership tests.
    objc_setAssociatedObject(object, &key, value, OBJC_ASSOCIATION_ASSIGN);
    id retrieved = objc_getAssociatedObject(object, &key);
    int ok = retrieved == value;
    objc_setAssociatedObject(object, &key, nil, OBJC_ASSOCIATION_ASSIGN);
    ok = ok && objc_getAssociatedObject(object, &key) == nil;
    // Keep both objects alive until process exit.  Disposing the associated
    // value would exercise its release hook from the runtime's association
    // cleanup path, which is a separate ABI-sensitive concern.
    printf("objc-associated-objects: %d\n", ok ? 42 : 0);
    return ok ? 0 : 1;
}
