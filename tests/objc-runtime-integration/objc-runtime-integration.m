#include <stdio.h>
#include <string.h>
#include <objc/runtime.h>

static char associationKey;

typedef struct
{
    int x;
    int y;
    int z;
} RuntimeTriple;

__attribute__((objc_root_class))
@interface RuntimeBase
{
    Class isa;
}
+ (id)new;
+ (int)answer;
- (id)retain;
- (oneway void)release;
- (int)value;
- (RuntimeTriple)triple;
@end

@interface RuntimeDerived : RuntimeBase @end
@protocol RuntimeProtocol
+ (int)protocolValue;
@end
@interface RuntimeDerived () <RuntimeProtocol> @end

@implementation RuntimeBase
+ (id)new { return class_createInstance(self, 0); }
+ (int)answer { return 40; }
- (id)retain { return self; }
- (oneway void)release {}
- (int)value { return 9; }
- (RuntimeTriple)triple { return (RuntimeTriple){ 1, 2, 3 }; }
@end

@implementation RuntimeDerived
+ (int)answer { return [super answer] + 2; }
+ (int)protocolValue { return 11; }
@end

@interface RuntimeDerived (Extra)
+ (int)categoryValue;
@end
@implementation RuntimeDerived (Extra)
+ (int)categoryValue { return [self answer]; }
@end

static int replacement(id self, SEL selector)
{
    (void)self;
    (void)selector;
    return 77;
}

static RuntimeBase *possiblyNilObject(RuntimeBase *object, BOOL useObject)
{
    return useObject ? object : nil;
}

int main(void)
{
    RuntimeDerived *object = [RuntimeDerived new];
    Class base = objc_getClass("RuntimeBase");
    Class derived = objc_getClass("RuntimeDerived");
    SEL valueSelector = @selector(value);
    Method valueMethod = class_getInstanceMethod(derived, valueSelector);

    int checks = 0;
    checks += base && derived && valueMethod && object;
    checks += class_getSuperclass(derived) == base;
    checks += class_respondsToSelector(object_getClass(object), valueSelector);
    checks += class_conformsToProtocol(derived, @protocol(RuntimeProtocol));
    checks += [RuntimeDerived answer] == 42;
    checks += [RuntimeDerived protocolValue] == 11;
    checks += [RuntimeDerived categoryValue] == 42;
    checks += [object value] == 9;
    volatile BOOL useObject = NO;
    RuntimeBase *possiblyNil = possiblyNilObject(object, useObject);
    RuntimeTriple possiblyNilTriple = [possiblyNil triple];
    checks += [possiblyNil value] == 0;
    checks += possiblyNilTriple.x == 0 && possiblyNilTriple.y == 0 &&
              possiblyNilTriple.z == 0;
    RuntimeBase *reallyNil = nil;
    RuntimeTriple reallyNilTriple = [reallyNil triple];
    checks += [reallyNil value] == 0;
    checks += reallyNilTriple.x == 0 && reallyNilTriple.y == 0 &&
              reallyNilTriple.z == 0;
    checks += sel_isEqual(method_getName(valueMethod), valueSelector);
    checks += strcmp(method_getTypeEncoding(valueMethod), "i8@0:4") == 0;

    class_replaceMethod(derived, valueSelector, (IMP)replacement, "i8@0:4");
    checks += [object value] == 77;
    checks += method_getImplementation(class_getInstanceMethod(derived, valueSelector)) ==
              (IMP)replacement;
    checks += [((id)nil) value] == 0;

    id associationValue = [RuntimeBase new];
    objc_setAssociatedObject(object, &associationKey, associationValue,
                             OBJC_ASSOCIATION_ASSIGN);
    checks += objc_getAssociatedObject(object, &associationKey) == associationValue;
    objc_setAssociatedObject(object, &associationKey, nil, OBJC_ASSOCIATION_ASSIGN);
    checks += objc_getAssociatedObject(object, &associationKey) == nil;

    SEL answerSelector = @selector(answer);
    IMP answerImplementation = objc_msg_lookup((id)derived, answerSelector);
    checks += ((int (*)(id, SEL))answerImplementation)((id)derived, answerSelector) == 42;

    object_dispose(associationValue);
    object_dispose(object);
    printf("objc-runtime-integration: %d/%d\n", checks, 20);
    return checks == 20 ? 0 : 1;
}
