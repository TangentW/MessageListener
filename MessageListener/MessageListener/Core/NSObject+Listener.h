//
//  NSObject+Listener.h
//  MessageListener
//
//  Created by Tan on 20/10/2017.
//  Copyright © 2017 Tangent. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^MessageDidSendCallback) (NSArray * _Nonnull);

@interface NSObject (Listener)


/**
 Active listening
 */
- (void)listen:(nonnull SEL)selector in:(nullable Protocol *)protocol with:(nonnull MessageDidSendCallback)callback;

- (void)listen:(nonnull SEL)selector with:(nonnull MessageDidSendCallback)callback;

@end
