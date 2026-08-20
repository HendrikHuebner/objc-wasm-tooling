#import <Foundation/Foundation.h>
#include <stdio.h>

@interface Model : NSObject
@property (strong) NSString *name;
@property int value;
@end
@implementation Model
@synthesize name, value;
@end

@interface Observer : NSObject
@property int nameChanges;
@property int nameOldValues;
@property int scalarChanges;
@end
@implementation Observer
@synthesize nameChanges, nameOldValues, scalarChanges;
- (void)observeValueForKeyPath:(NSString *)path ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context
{
    (void)object;
    (void)context;
    if ([path isEqualToString:@"name"] &&
        [change objectForKey:NSKeyValueChangeNewKey] != nil)
        self.nameChanges++;
    if ([path isEqualToString:@"name"] &&
        [change objectForKey:NSKeyValueChangeOldKey] != nil)
        self.nameOldValues++;
    if ([path isEqualToString:@"value"] &&
        [[change objectForKey:NSKeyValueChangeNewKey] intValue] == 42)
        self.scalarChanges++;
}
@end

int main(void)
{
    @autoreleasepool
    {
        Model *model = [Model new];
        Observer *observer = [Observer new];
        [model addObserver:observer forKeyPath:@"name"
                   options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                   context:0];
        [model addObserver:observer forKeyPath:@"value"
                   options:NSKeyValueObservingOptionNew context:0];
        model.name = @"first";
        model.name = @"second";
        model.value = 42;
        [model removeObserver:observer forKeyPath:@"name"];
        [model removeObserver:observer forKeyPath:@"value"];

        int checks = observer.nameChanges == 2;
        checks += observer.nameOldValues == 2;
        checks += observer.scalarChanges == 1;
        printf("kvo-integration: %d/3\n", checks);
        return checks == 3 ? 0 : 1;
    }
}
