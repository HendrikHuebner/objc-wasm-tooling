#import <Foundation/Foundation.h>
#include <stdio.h>

typedef struct { int number; double fraction; } CustomValue;

@interface Model : NSObject
@property CustomValue value;
@end
@implementation Model
@synthesize value;
@end

@interface Observer : NSObject
@property int changes;
@end
@implementation Observer
@synthesize changes;
- (void)observeValueForKeyPath:(NSString *)path ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context
{
    (void)object; (void)context;
    CustomValue value;
    [[change objectForKey:NSKeyValueChangeNewKey] getValue:&value];
    if ([path isEqualToString:@"value"] && value.number == 42 &&
        value.fraction == 0.5)
        self.changes++;
}
@end

int main(void)
{
    @autoreleasepool {
        Model *model = [Model new];
        Observer *observer = [Observer new];
        [model addObserver:observer forKeyPath:@"value"
                   options:NSKeyValueObservingOptionNew context:0];
        model.value = (CustomValue){42, 0.5};
        [model removeObserver:observer forKeyPath:@"value"];
        int ok = observer.changes == 1;
        printf("kvo-struct: %d\n", ok ? 42 : 0);
        return ok ? 0 : 1;
    }
}
