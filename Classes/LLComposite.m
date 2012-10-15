#import "LLComposite.h"
#import "LLComponent.h"

#include <objc/runtime.h>

#pragma mark C

static __strong NSMutableDictionary * _classComponents;
static __strong NSMutableDictionary * _classComponentSelectorCache;
static __strong NSMutableDictionary * _classComponentHierarchyCache;
static LLCompositeForwarderOptions _classForwarderOptions = LLCompositeForwarderOptionUseCache;

@implementation NSObject(LLIntrospectionExtensions)

- (void) ll_iterateInstanceMethodsWithBlock:(LLMethodIterator)iterator
{
    unsigned int count = 0;
    Method * methods = class_copyMethodList([self class], &count);
    
    for(int i=0; i < count; i++)
    {
        Method method = methods[i];
        struct objc_method_description * description = method_getDescription(method);
        
        SEL selector = description->name;
        char * types = description->types;
        IMP imp = [self methodForSelector:selector];
        
        iterator(self, method, selector, imp, types);
    }
}

- (void) ll_iterateHierarchyWithBlock:(LLClassIterator)iterator
{
    unsigned int count = 0;
    Class thisClass = [self class];
    Class currentClass = thisClass;
    
    while (currentClass != nil) {
        iterator(thisClass, currentClass, count);
        
        currentClass = class_getSuperclass(currentClass);
        count++;
    }
    
}

@end



#pragma mark Objective-C

@interface LLCompositeForwarder()

@end

@implementation LLCompositeForwarder
{
    // Forwarder Storage
    __strong NSMutableArray * _components;
    __strong NSMutableDictionary * _cache;
    
    // Parent Class
    __weak id _parent;
    
    // TODO: Dynamic Instances
    __strong Class _dynamicClass;
    __strong id _dynamicInstance;
}

@synthesize options = _options;

- (id) initWithOptions:(LLCompositeForwarderOptions)options andParent:(id)parent
{
    if(self = [super init])
    {
        _components = [[NSMutableArray alloc] init];
        _options = options;
        _parent = parent;
        
        if(BIT_IS_ON(_options, LLCompositeForwarderOptionUseCache))
           _cache = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}


#pragma mark Components


- (void) addComponent:(id)component
{
    [_components addObject:component];
    
    // This will create the dynamic class and instance if necessary
    if(BIT_IS_ON(_options, LLCompositeForwarderOptionCreateClass) &&
       !_dynamicInstance)
    {
        NSString * className = [NSString stringWithFormat:@"%@_LLCOMPOSITEFORWARDER_CREATED_CLASS_%@",NSStringFromClass([self class]),@""];
        _dynamicClass = objc_allocateClassPair([LLComponent class], [className cStringUsingEncoding:NSASCIIStringEncoding], 0);
        objc_registerClassPair(_dynamicClass);
        _dynamicInstance = [_dynamicClass componentWithComposite:[component composite]];
    }
    
    // This will manually implement all methods
    if(BIT_IS_ON(_options, LLCompositeForwarderOptionModifyClass) ||
       BIT_IS_ON(_options, LLCompositeForwarderOptionUseCache) ||
       BIT_IS_ON(_options, LLCompositeForwarderOptionCreateClass))
    {
       [self iterateThroughMethods:component];
    }
}


- (void) removeComponent:(id)component
{
    if([_components containsObject:component])
    {
        [_components removeObject:component];
        
        // Update cache
        if(BIT_IS_ON(_options, LLCompositeForwarderOptionUseCache))
        {
            [component ll_iterateInstanceMethodsWithBlock:^(id obj, Method method, SEL sel, IMP imp, char *types) {
                if(BIT_IS_ON(_options, LLCompositeForwarderOptionUseCache))
                {
                    NSMutableArray * components = [_cache objectForKey:NSStringFromSelector(sel)];
                    [components removeObject:obj];
                }
            }];
        }
    }
}



+ (void) addComponent:(id)component toClass:(Class)class
{
    // Extract list of components for this class
    NSString * classString = NSStringFromClass(class);
    NSMutableArray * classComponents = [[self classComponents] objectForKey:classString];
    if(!classComponents)
    {
        classComponents = [[NSMutableArray alloc] init];
        [[self classComponents] setObject:classComponents forKey:classString];
    }
    // Add the component to the component list for this class
    [classComponents addObject:component];
    
    if(BIT_IS_ON(_classForwarderOptions, LLCompositeForwarderOptionUseCache))
    {
        [component ll_iterateInstanceMethodsWithBlock:^(id obj, Method method, SEL sel, IMP imp, char *types) {
            NSString * selectorString = NSStringFromSelector(sel);
            NSMutableArray * selectorClassComponents = [_classComponentSelectorCache objectForKey:selectorString];
            
            if(!selectorClassComponents)
            {
                selectorClassComponents = [NSMutableArray array];
                [_classComponentSelectorCache setObject:component forKey:selectorString];
            }
            
            [selectorClassComponents addObject:component];
        }];
    }
}


+ (void) removeComponent:(id)component fromClass:(Class)class
{
    NSString * classString = NSStringFromClass(class);
    NSArray * classComponents = [[self classComponents] objectForKey:classString];
    if(!classComponents)
        classComponents = [[NSMutableArray alloc] init];
    
    [[self classComponents] setObject:classComponents forKey:classString];

    if(BIT_IS_ON(_classForwarderOptions, LLCompositeForwarderOptionUseCache))
    {
        [component ll_iterateInstanceMethodsWithBlock:^(id obj, Method method, SEL sel, IMP imp, char *types) {
            if(BIT_IS_ON(_classForwarderOptions, LLCompositeForwarderOptionUseCache))
            {
                NSString * selectorString = NSStringFromSelector(sel);
                NSMutableArray * components = [_classComponentSelectorCache objectForKey:selectorString];
                
                [components removeObject:obj];
            }
        }];
        
        if([self classesInHierarchy:self] == nil)
        {
            NSMutableArray * array = [[NSMutableArray alloc] init];
            
            [component ll_iterateHierarchyWithBlock:^(__unsafe_unretained Class originalClass, __unsafe_unretained Class class, int depth) {
                [array addObject:NSStringFromClass(class)];
            }];
            
            [[self classComponentHeirarchyCache] setObject:array forKey:NSStringFromClass(self)];
        }
    }
}



#pragma mark Private Methods


+ (NSMutableDictionary *) classComponents
{
    if(!_classComponents)
        _classComponents = [[NSMutableDictionary alloc] init];
    
    return _classComponents;
}

+ (NSMutableDictionary *) classComponentSelectorCache
{
    if(!_classComponentSelectorCache)
        _classComponentSelectorCache = [[NSMutableDictionary alloc] init];
    
    return _classComponentSelectorCache;
}


+ (NSMutableDictionary *) classComponentHeirarchyCache
{
    if(!_classComponentHierarchyCache)
        _classComponentHierarchyCache = [[NSMutableDictionary alloc] init];
    
    return _classComponentSelectorCache;
}


+ (NSArray *) classesInHierarchy:(Class)class
{
    if(BIT_IS_ON(_classForwarderOptions, LLCompositeForwarderOptionUseCache))
    {
        return [[self classComponentSelectorCache] objectForKey:NSStringFromClass(class)];
    }
    else
    {
        NSMutableArray * array = [[NSMutableArray alloc] init];
        while(class != nil){
            [array addObject:NSStringFromClass(class)];
            class = [class superclass];
        }
        return array;
    }
}


- (void) iterateThroughMethods:(id)component
{
    [component ll_iterateInstanceMethodsWithBlock:^(id obj, Method method, SEL sel, IMP imp, char *types) {
        
        if(BIT_IS_ON(_options, LLCompositeForwarderOptionModifyClass))
        {
            class_addMethod([self class], sel, imp, types);
        }
        
        if(BIT_IS_ON(_options, LLCompositeForwarderOptionCreateClass))
        {
            class_addMethod(_dynamicClass, sel, imp, types);
        }
        
        if(BIT_IS_ON(_options, LLCompositeForwarderOptionUseCache))
        {
            NSString * selectorString = NSStringFromSelector(sel);
            NSMutableArray * components = [_cache objectForKey:selectorString];
            
            if(!components)
            {
                components = [NSMutableArray array];
                [_cache setObject:component forKey:selectorString];
            }
            
            [components addObject:component];
        }

    }];
}


#pragma mark Public Methods


- (NSUInteger) componentImplementationCount:(SEL)aSelector
{
    __block NSUInteger impCount = 0;
    
    // Instance
    if(BIT_IS_ON(_options, LLCompositeForwarderOptionUseCache))
    {
        impCount += [[_cache objectForKey:NSStringFromSelector(aSelector)] count];
    }
    else
    {
        [_components enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if([obj respondsToSelector:aSelector])  impCount++;
        }];
    }
    
    // Class
    if(BIT_IS_ON(_classForwarderOptions, LLCompositeForwarderOptionUseCache))
    {
        impCount += [[_cache objectForKey:NSStringFromSelector(aSelector)] count];
    }
    else
    {
        [_classComponents enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
           [obj enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
              if([obj respondsToSelector:aSelector])
                  impCount++;
           }];
        }];
    }
    
    return impCount;
}

- (NSArray *) componentsImplementingSelector:(SEL)aSelector
{
    NSMutableArray * array = [[NSMutableArray alloc] init];
    
    // Instance
    if(BIT_IS_ON(_options, LLCompositeForwarderOptionUseCache))
    {
        [array addObjectsFromArray:[_cache objectForKey:NSStringFromSelector(aSelector)]];
    }
    else
    {
        NSIndexSet * indexSet = [_components indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return [obj respondsToSelector:aSelector];
        }];
        [array addObjectsFromArray:[_components objectsAtIndexes:indexSet]];
    }
    
    // Class
    NSArray * classHeirarchy = [LLCompositeForwarder classesInHierarchy:[self class]];
    if(BIT_IS_ON(_classForwarderOptions, LLCompositeForwarderOptionUseCache))
    {
        [classHeirarchy enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [array addObjectsFromArray:[_classComponentSelectorCache objectForKey:obj]];
        }];
    }
    else
    {
        [classHeirarchy enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [obj enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [array addObject:obj];
            }];
        }];
    }
    
    return array;
}

#pragma mark - Message Forwarding

/*
 * A Forwarding Target to a component will only result in one call to a component
 * If more than one component implements the same selector, the first will get used
 */ 
- (id)forwardingTargetForSelector:(SEL)aSelector
{
    if(BIT_IS_ON(_options, LLCompositeForwarderOptionCreateClass))
    {
        return _dynamicClass;
    }
        
    // Only proceed with simple forwarding if the component implentation count is 1
    NSArray * components = [self componentsImplementingSelector:aSelector];
    if([components count] == 0)
    {
        return nil;
    }
    else if([components count] == 1)
    {
        return [components objectAtIndex:0];
    }
    
    // This will cause -forwardInvocation to kick in for multiple component implementations
    return nil;
}

/*
 * This class respods to all selectors it implements and all component selectors
 */
- (BOOL)respondsToSelector:(SEL)aSelector
{
    BOOL ret = [super respondsToSelector:aSelector];
    [super respondsToSelector:aSelector];
    
    if(ret)
        return YES;
    
    NSUInteger count = [self componentImplementationCount:aSelector];
    if(count > 0)
        return YES;
    
    return NO;
}

/*
 * Needed for -forwardInvocation: to work
 */
- (NSMethodSignature *) methodSignatureForSelector:(SEL)aSelector
{
    NSMethodSignature * signature = [super methodSignatureForSelector:aSelector];
    if(!signature)
    {
        NSArray * components = [self componentsImplementingSelector:aSelector];
        for(id obj in components)
        {
            signature = [obj methodSignatureForSelector:aSelector];
        }
    }
    
    return signature;
}


/*
 * The essence of the forward invocation, allows the components to perform
 * each of the invocations, not just the first
 */
- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSInteger invocations = 0;
    NSArray * components = [self componentsImplementingSelector:anInvocation.selector];
    
    for(id obj in components)
    {
        [anInvocation invokeWithTarget:obj];
        invocations++;
    }
    
    // Call super on no forwarding
    if(invocations == 0)
    {
        return [super forwardInvocation:anInvocation];
    }
}


/*
 * Overridden so that the composite forwarder considers itself part of the 
 * class for all its components.
 */
- (BOOL) isKindOfClass:(Class)aClass
{
    if([super isKindOfClass:aClass])
        return YES;
    
    for(id obj in _components)
    {
        if([obj isKindOfClass:aClass])
            return YES;
    }
    
    //TODO: Class Components
    
    // Exit now
    return NO;
}

@end


#pragma mark -


@implementation NSObject(LLCompositeExtension)

const static char * compositeForwarderKey = "__forwarder";

- (void) addComponent:(id)component
{
    // Create the forwarder if necessary
    LLCompositeForwarder * forwarder = [self compositeForwarder];
    if(!forwarder)
    {
        [self createForwarder];
        forwarder = [self compositeForwarder];
    }
    
    // Enable Forwarding if necessary
    if(![[self class] isForwardingEnabledOnClass:[self class]])
    {
        [[self class] enableForwardingOn];
    }
    
    [forwarder addComponent:component];
}


- (void) removeComponent:(id)component
{
    LLCompositeForwarder * forwarder = [self compositeForwarder];
    [forwarder removeComponent:component];
}


+ (void) addComponent:(id)component
{
    [LLCompositeForwarder addComponent:component toClass:self];
}


+ (void) removeComponent:(id)component
{
    [LLCompositeForwarder removeComponent:component fromClass:self];
}

- (LLCompositeForwarder *) compositeForwarder
{
    LLCompositeForwarder * forwarder = objc_getAssociatedObject(self, compositeForwarderKey);
    return forwarder;
}

#pragma mark - Implmenentation of Forwarding to Composite Forwarder

#pragma mark First Set Does Triaging

- (BOOL)isKindOfClass__triage:(Class)aClass
{
    SEL originalSelector = [self getOriginalIMPSelector:_cmd];
    BOOL (* isKindFP)(id, SEL, id) = (BOOL (*)(id, SEL, id)) objc_msgSend;
    BOOL isKind = isKindFP(self, originalSelector, aClass);
    
    if(!isKind)
    {
        isKind = [self isKindOfClass__llcomposite:aClass];
    }
    
    return isKind;
}


- (BOOL)respondsToSelector__triage:(SEL)aSelector
{
    SEL originalSelector = [self getOriginalIMPSelector:_cmd];
    BOOL (* respondsFP)(id, SEL, SEL) = (BOOL (*)(id, SEL, SEL)) objc_msgSend;
    BOOL responds = respondsFP(self, originalSelector, aSelector);
    
    if(!responds)
    {
        responds = [self respondsToSelector__llcomposite:aSelector];
    }
    
    return responds;
}


- (id) forwardingTargetForSelector__triage:(SEL)aSelector
{
    SEL originalSelector = [self getOriginalIMPSelector:_cmd];
    id forwardingTarget = objc_msgSend(self, originalSelector, aSelector);
    
    if(!forwardingTarget)
    {
        forwardingTarget = [self forwardingTargetForSelector__llcomposite:aSelector];
    }
    
    return forwardingTarget;
}


- (void) forwardInvocation__triage:(NSInvocation *)anInvocation
{
    // Perform original forward invocation
    SEL originalSelector = [self getOriginalIMPSelector:_cmd];
    objc_msgSend(self, originalSelector, anInvocation);
    
    [self forwardInvocation__llcomposite:anInvocation];
}


- (NSMethodSignature *) methodSignatureForSelector__triage:(SEL)aSelector
{
    SEL originalSelector = [self getOriginalIMPSelector:_cmd];
    NSMethodSignature * signature = objc_msgSend(self, originalSelector, aSelector);
    
    if(!signature)
    {
        signature = [self methodSignatureForSelector__llcomposite:aSelector];
    }
    
    return signature;
}


#pragma mark Second Set Performs Forwarding


- (BOOL)isKindOfClass__llcomposite:(Class)aClass
{
    return [[self compositeForwarder] isKindOfClass:aClass];
}


- (BOOL)respondsToSelector__llcomposite:(SEL)aSelector
{
    return [[self compositeForwarder] respondsToSelector:aSelector];
}


- (id) forwardingTargetForSelector__llcomposite:(SEL)aSelector
{
    return [self compositeForwarder];
}


- (void) forwardInvocation__llcomposite:(NSInvocation *)anInvocation
{
    return [[self compositeForwarder] forwardInvocation:anInvocation];
}


- (NSMethodSignature *) methodSignatureForSelector__llcomposite:(SEL)aSelector
{
    return [[self compositeForwarder] methodSignatureForSelector:aSelector];
}


#pragma mark - Private Methods

- (SEL) newSEL:(SEL)selector appendingStringToFirstArg:(NSString *)str
{
    NSString * selString = NSStringFromSelector(selector);
    NSArray * subStrings = [selString componentsSeparatedByString:@":"];
    NSMutableString * string = [[NSMutableString alloc] init];
    
    if([[subStrings objectAtIndex:0] isEqualToString:selString])
    {
        [string appendString:selString];
    }
    else
    {
        [subStrings enumerateObjectsWithOptions:0 usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if([obj length] > 0)
        {
            [string appendString:obj];
            if(idx == 0)
            {
                [string appendString:str];
            }
            [string appendString:@":"];
        }
        }];
    }
    

    const char * selCString = [string cStringUsingEncoding:NSASCIIStringEncoding];
    SEL newSel = sel_registerName(selCString);
    return newSel;
}


- (SEL) getOriginalIMPSelector:(SEL)selector
{
    return [self newSEL:selector appendingStringToFirstArg:@"__original"];
}


- (SEL) getCompositeIMPSelector:(SEL)selector
{
    return [self newSEL:selector appendingStringToFirstArg:@"__composite"];
}


- (SEL) getTriageIMPSelector:(SEL)selector
{
    return [self newSEL:selector appendingStringToFirstArg:@"__triage"];
}


- (void) createForwarder
{
    LLCompositeForwarder * forwarder = [self compositeForwarder];
    if(!forwarder)
    {
        forwarder = [[LLCompositeForwarder alloc] initWithOptions:LLCompositeForwarderOptionNone andParent:self];
        objc_setAssociatedObject(self, compositeForwarderKey, forwarder, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

+ (BOOL) isForwardingEnabledOnClass:(Class)class
{
    SEL selector = @selector(respondsToSelector:);
    IMP currentIMP = class_getMethodImplementation(class, selector);
    IMP triageIMP = class_getMethodImplementation(class, [self getTriageIMPSelector:selector]);
    
    // This checks that the current implementation of respondsToSelector is the Swizzled __triage Method
    return currentIMP == triageIMP;
}


+ (void) enableCompositeForwardingOnClass:(Class)class
{
    void (^enableForwardingForSelector)(SEL, Class, IMP) = ^(SEL selector, Class class, IMP newIMP){
        SEL originalSelector = [self getOriginalIMPSelector:selector];
        
        //Only will occur if the original method has been moved to originalSelector SEL
        if(![self respondsToSelector__llcomposite:originalSelector])
        {
            // Get the IMPS
            IMP originalIMP = class_getMethodImplementation(class, selector);
            const char * typeEncoding = method_getTypeEncoding(class_getInstanceMethod(class, selector));
            
            // Create new Method using original implementation with changed selector
            BOOL result = class_addMethod(class, originalSelector, originalIMP, typeEncoding);
            NSAssert(result, @"Failed to Add Method");
            
            // Replace original implementation with the Triaging method
            class_replaceMethod(class, selector, newIMP, typeEncoding);
        }
    };
    
    void (^enableForwardingForSelectorComposite)(SEL, Class) = ^(SEL selector, Class class){
        SEL compositeSEL = [self getTriageIMPSelector:selector];
        IMP triageIMP = class_getMethodImplementation(class, compositeSEL);
        enableForwardingForSelector(selector, class, triageIMP);
    };

    // -isKindOfClass
    SEL selector = @selector(isKindOfClass:);
    enableForwardingForSelectorComposite(selector, class);
    
    // -forwardInvocation
    selector = @selector(forwardInvocation:);
    enableForwardingForSelectorComposite(selector, class);
    
    // -methodSignatureForSelector
    selector = @selector(methodForSelector:);
    enableForwardingForSelectorComposite(selector, class);
    
    // -respondsToSelector
    selector = @selector(respondsToSelector:);
    enableForwardingForSelectorComposite(selector, class);
    
    // -forwardingTargetForSelector
    selector = @selector(forwardingTargetForSelector:);
    enableForwardingForSelectorComposite(selector, class);
}

@end