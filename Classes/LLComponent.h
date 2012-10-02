#import <UIKit/UIKit.h>

@interface LLComponent : NSObject
{
    __weak id _composite;
}

- (id) initWithComposite:(id)composite;
+ (id) componentWithComposite:(id)composite;

@property(nonatomic, readonly, weak) id composite;

@end