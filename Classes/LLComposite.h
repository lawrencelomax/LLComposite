#import <UIKit/UIKit.h>

#include <objc/runtime.h>

#pragma mark Typedefs

typedef void (^LLMethodIterator)(id obj, Method method, SEL sel, IMP imp, char * types);
typedef void (^LLClassIterator)(Class originalClass, Class class, int depth);

@interface NSObject(LLIntrospectionExtensions)

- (void) ll_iterateInstanceMethodsWithBlock:(LLMethodIterator)iterator;

@end

@protocol LLComposite<NSObject>

- (void) addComponent:(id)component;
- (void) removeComponent:(id)component;

+ (void) addComponent:(id)component;
+ (void) removeComponent:(id)component;

@end

typedef enum{
    LLCompositeForwarderOptionNone = 0,
    LLCompositeForwarderOptionModifyClass = 1 << 1,
    LLCompositeForwarderOptionUseCache = 1 << 2,
    LLCompositeForwarderOptionCreateClass = 1 << 3
}LLCompositeForwarderOptions;

@interface LLCompositeForwarder : NSObject<LLComposite>

- (id) initWithOptions:(LLCompositeForwarderOptions)options andParent:(id)parent;

@property(nonatomic, readonly) LLCompositeForwarderOptions options;

- (NSUInteger) componentImplementationCount:(SEL)aSelector;
- (NSArray *) componentsImplementingSelector:(SEL)aSelector;

@end

@interface NSObject(LLCompositeExtension)<LLComposite>

- (BOOL)isKindOfClass__llcomposite:(Class)aClass;
- (BOOL)respondsToSelector__llcomposite:(SEL)aSelector;
- (id)forwardingTargetForSelector__llcomposite:(SEL)aSelector;
- (void) forwardInvocation__llcomposite:(NSInvocation *)anInvocation;
- (NSMethodSignature *) methodSignatureForSelector__llcomposite:(SEL)aSelector;


@end