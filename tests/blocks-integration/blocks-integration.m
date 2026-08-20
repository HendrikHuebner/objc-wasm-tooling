#include <stdio.h>
#include <objc/runtime.h>
#include <Block.h>

typedef struct
{
    int x;
    int y;
    int z;
} RuntimeTriple;

typedef int (^IntBlock)(int);

static int applyBlock(IntBlock block, int value)
{
    return block(value);
}

static IntBlock makeAdder(int base)
{
    return Block_copy(^(int value) { return base + value; });
}

static int (^globalBlock)(int) = ^(int value) { return value * 2; };

__attribute__((objc_root_class))
@interface BlockHolder
{
    Class isa;
    IntBlock _handler;
}
+ (id)new;
- (void)setHandler:(IntBlock)handler;
- (int)invoke:(int)value;
@end

@implementation BlockHolder
+ (id)new { return class_createInstance(self, 0); }
- (void)setHandler:(IntBlock)handler
{
    if (_handler != nil)
        Block_release(_handler);
    _handler = handler == nil ? nil : Block_copy(handler);
}
- (int)invoke:(int)value { return _handler(value); }
@end

int main(void)
{
    int checks = 0;
    int captured = 40;
    IntBlock stackBlock = ^(int value) { return captured + value; };
    IntBlock heapBlock = Block_copy(stackBlock);
    checks += stackBlock(2) == 42;
    checks += heapBlock(2) == 42;
    checks += applyBlock(heapBlock, 2) == 42;

    IntBlock adder = makeAdder(40);
    checks += adder(2) == 42;
    Block_release(adder);

    __block int mutableCapture = 0;
    IntBlock mutatingBlock = Block_copy(^(int value) {
        mutableCapture += value;
        return mutableCapture;
    });
    checks += mutatingBlock(19) == 19;
    checks += mutatingBlock(23) == 42;
    checks += mutableCapture == 42;
    Block_release(mutatingBlock);

    RuntimeTriple capturedTriple = { 4, 2, 8 };
    IntBlock nestedBlock = ^(int value) {
        IntBlock inner = ^(int innerValue) {
            return innerValue + capturedTriple.x + capturedTriple.y + capturedTriple.z;
        };
        return inner(value);
    };
    checks += nestedBlock(28) == 42;
    checks += globalBlock(21) == 42;

    IntBlock globalCopy = Block_copy(globalBlock);
    checks += globalCopy(21) == 42;
    Block_release(globalCopy);

    IntBlock constantBlock = Block_copy(^(int value) { return value + 40; });
    checks += constantBlock(2) == 42;
    Block_release(constantBlock);

    BlockHolder *holder = [BlockHolder new];
    [holder setHandler:heapBlock];
    checks += [holder invoke:2] == 42;
    [holder setHandler:nestedBlock];
    checks += [holder invoke:28] == 42;
    [holder setHandler:nil];

    Block_release(heapBlock);
    object_dispose((id)holder);
    printf("blocks-integration: %d/13\n", checks);
    return checks == 13 ? 0 : 1;
}
