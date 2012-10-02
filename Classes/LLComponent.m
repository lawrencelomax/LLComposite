#import "LLComponent.h"

@implementation LLComponent

@synthesize composite = _composite;

- (id) initWithComposite:(id)composite
{
    if (self = [super init])
    {
        _composite = composite;
    }
    return self;
}


+ (id) componentWithComposite:(id)composite
{
    id component = [[self alloc] initWithComposite:composite];
    return component;
}


@end