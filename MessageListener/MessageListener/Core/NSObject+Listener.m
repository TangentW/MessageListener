//
//  NSObject+Listener.m
//  MessageListener
//
//  Created by Tan on 20/10/2017.
//  Copyright © 2017 Tangent. All rights reserved.
//

#import "NSObject+Listener.h"
#import <objc/runtime.h>
#import <objc/message.h>

static SEL _Nonnull _modifySelector(SEL _Nonnull selector);
static Class _Nullable _swizzleClass(id _Nonnull self);

@implementation NSObject (Listener)

- (void)listen:(SEL)selector in:(Protocol *)protocol with:(MessageDidSendCallback)callback {
    SEL runtimeSelector = _modifySelector(selector);
    // 引用闭包
    objc_setAssociatedObject(self, runtimeSelector, callback, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // isa-swizzling
    Class interlayerClass = _swizzleClass(self);
    if (!interlayerClass) return;

    Method originalMethod = class_getInstanceMethod(interlayerClass, selector);
    IMP originalImplementation = method_getImplementation(originalMethod);

    // 判断是否具有该方法
    // 如果没有，试图在指定的协议中寻找
    if (!originalMethod) {
        if (!protocol) return;
        struct objc_method_description des = protocol_getMethodDescription(protocol, selector, YES, YES);
        if (!des.name)
            des = protocol_getMethodDescription(protocol, selector, NO, YES);
        if (des.types)
            class_addMethod(interlayerClass, selector, _objc_msgForward, des.types);
    }
    // 如果原始方法没有做替换
    // 则将原始方法的实现改为_objc_msgForward
    else if (originalImplementation != _objc_msgForward) {
        const char *typeEncoding = method_getTypeEncoding(originalMethod);
        class_addMethod(interlayerClass, runtimeSelector, originalImplementation, typeEncoding);
        class_replaceMethod(interlayerClass, selector, _objc_msgForward, typeEncoding);
    }
}

- (void)listen:(SEL)selector with:(MessageDidSendCallback)callback {
    [self listen:selector in:nil with:callback];
}

@end

#pragma mark - Private API
// 用于在原有的基础上标示Selector以及中间层类对象的名字，便于区分
static NSString * const _prefixName = @"_Listener_";

// 关联对象Key，是否已经存在中间层类对象
static void *_interlayerClassExist = &_interlayerClassExist;

// 获取参数
static id _Nonnull _getArgument(NSInvocation * _Nonnull invocation, NSUInteger index) {
    const char *argumentType = [invocation.methodSignature getArgumentTypeAtIndex:index];

#define RETURN_VALUE(type) \
else if (strcmp(argumentType, @encode(type)) == 0) {\
type val = 0; \
[invocation getArgument:&val atIndex:index]; \
return @(val); \
}

    // Skip const type qualifier.
    if (argumentType[0] == 'r') {
        argumentType++;
    }

    if (strcmp(argumentType, @encode(id)) == 0
        || strcmp(argumentType, @encode(Class)) == 0
        || strcmp(argumentType, @encode(void (^)(void))) == 0
        ) {
        __unsafe_unretained id argument = nil;
        [invocation getArgument:&argument atIndex:index];
        return argument;
    }
    RETURN_VALUE(char)
    RETURN_VALUE(short)
    RETURN_VALUE(int)
    RETURN_VALUE(long)
    RETURN_VALUE(long long)
    RETURN_VALUE(unsigned char)
    RETURN_VALUE(unsigned short)
    RETURN_VALUE(unsigned int)
    RETURN_VALUE(unsigned long)
    RETURN_VALUE(unsigned long long)
    RETURN_VALUE(float)
    RETURN_VALUE(double)
    RETURN_VALUE(BOOL)
    RETURN_VALUE(const char *)
    else {
        NSUInteger size = 0;
        NSGetSizeAndAlignment(argumentType, &size, NULL);
        NSCParameterAssert(size > 0);
        uint8_t data[size];
        [invocation getArgument:&data atIndex:index];

        return [NSValue valueWithBytes:&data objCType:argumentType];
    }
}

static NSArray * _Nonnull _getArguments(NSInvocation * _Nonnull invocation) {
    NSUInteger count = invocation.methodSignature.numberOfArguments;
    // 除去开头的两个参数(id, SEL)，代表实例自己以及方法的选择器
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:count - 2];
    for (NSUInteger i = 2; i < count; i ++)
        [arr addObject:_getArgument(invocation, i)];
    return arr;
}

// 修饰Selector，返回经过前缀名拼接的Selector
static SEL _Nonnull _modifySelector(SEL _Nonnull selector) {
    NSString *originalName = NSStringFromSelector(selector);
    return NSSelectorFromString([_prefixName stringByAppendingString:originalName]);
}

// 混淆forwardInvocation方法
static void _swizzleForwardInvocation(Class _Nonnull class) {
    SEL fiSelector = @selector(forwardInvocation:);
    Method fiMethod = class_getInstanceMethod(class, fiSelector);
    void (*originalFiImp)(id, SEL, NSInvocation *) = (void *)method_getImplementation(fiMethod);
    id newFiImp = ^(id self, NSInvocation *invocation) {
        SEL runtimeSelector = _modifySelector(invocation.selector);
        MessageDidSendCallback callback = (MessageDidSendCallback)objc_getAssociatedObject(self, runtimeSelector);
        if (!callback) {
            if (originalFiImp)
                originalFiImp(self, fiSelector, invocation);
            else
                [self doesNotRecognizeSelector: invocation.selector];
        } else {
            if ([self respondsToSelector: runtimeSelector]) {
                invocation.selector = runtimeSelector;
                [invocation invoke];
            }
            callback(_getArguments(invocation));
        }
    };
    class_replaceMethod(class, fiSelector, imp_implementationWithBlock(newFiImp), method_getTypeEncoding(fiMethod));
}

// 混淆getClass方法
static void _swizzleGetClass(Class _Nonnull class, Class _Nonnull expectedClass) {
    SEL selector = @selector(class);
    Method getClassMethod = class_getInstanceMethod(class, selector);
    id newImp = ^(id self) {
        return expectedClass;
    };
    class_replaceMethod(class, selector, imp_implementationWithBlock(newImp), method_getTypeEncoding(getClassMethod));
}

// 混淆respondsToSelector方法
static void _swizzleRespondsToSelector(Class _Nonnull class) {
    SEL originalSelector = @selector(respondsToSelector:);
    Method method = class_getInstanceMethod(class, originalSelector);
    BOOL (*originalImplementation)(id, SEL, SEL) = (void *)method_getImplementation(method);
    id newImp = ^(id self, SEL selector) {
        Method method = class_getInstanceMethod(class, selector);
        if (method && method_getImplementation(method) == _objc_msgForward) {
            if (objc_getAssociatedObject(self, _modifySelector(selector)))
                return YES;
        }
        return originalImplementation(self, originalSelector, selector);
    };
    class_replaceMethod(class, originalSelector, imp_implementationWithBlock(newImp), method_getTypeEncoding(method));
}

// 混淆methodSignatureForSelector方法
static void _swizzleMethodSignatureForSelector(Class _Nonnull class) {
    SEL msfsSelector = @selector(methodSignatureForSelector:);
    Method method = class_getInstanceMethod(class, msfsSelector);
    id newIMP = ^(id self, SEL selector) {
        Method method = class_getInstanceMethod(class, selector);
        if (!method) {
            struct objc_super super = {
                self,
                class_getSuperclass(class)
            };
            NSMethodSignature *(*sendToSuper)(struct objc_super *, SEL, SEL) = (void *)objc_msgSendSuper;
            return sendToSuper(&super, msfsSelector, selector);
        }
        return [NSMethodSignature signatureWithObjCTypes: method_getTypeEncoding(method)];
    };
    class_replaceMethod(class, msfsSelector, imp_implementationWithBlock(newIMP), method_getTypeEncoding(method));
}

// isa-swizzling
static Class _Nullable _swizzleClass(id _Nonnull self) {
    Class originalClass = object_getClass(self);
    // 如果在之前已经替换了isa，则只需直接返回
    if ([objc_getAssociatedObject(self, _interlayerClassExist) boolValue])
        return originalClass;

    Class interlayerClass;

    Class presentClass = [self class];
    // 若之前没有手动替换过isa，但是两种方式获取到的Class不同
    // 说明此对象在之前被动态地替换isa，(可能是涉及到了KVO)
    // 这时候我们使用的中间层类对象就不需要动态创建一个了，直接使用之前动态创建的就行
    if (presentClass != originalClass) {
        // 重写方法
        _swizzleForwardInvocation(originalClass);
        _swizzleRespondsToSelector(originalClass);
        _swizzleMethodSignatureForSelector(originalClass);

        interlayerClass = originalClass;
    }
    else {
        const char *interlayerClassName = [_prefixName stringByAppendingString:NSStringFromClass(originalClass)].UTF8String;
        // 首先判断Runtime中是否已经注册过此中间层类
        // 若没有注册，则动态创建中间层类并且重写其中的指定方法，最后进行注册
        interlayerClass = objc_getClass(interlayerClassName);
        if (!interlayerClass) {
            // 基于原始的类对象创建新的中间层类对象
            interlayerClass = objc_allocateClassPair(originalClass, interlayerClassName, 0);
            if (!interlayerClass) return nil;

            // 重写方法
            _swizzleForwardInvocation(interlayerClass);
            _swizzleRespondsToSelector(interlayerClass);
            _swizzleMethodSignatureForSelector(interlayerClass);
            _swizzleGetClass(interlayerClass, presentClass);

            // 注册中间层类对象
            objc_registerClassPair(interlayerClass);
        }
    }
    // isa替换
    object_setClass(self, interlayerClass);
    objc_setAssociatedObject(self, _interlayerClassExist, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return interlayerClass;
}
