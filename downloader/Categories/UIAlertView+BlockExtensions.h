//
//  UIAlertView+BlockExtensions.h
//
//  Created by Tom Fewster on 07/10/2011.
//

@interface UIAlertView (BlockExtensions) <UIAlertViewDelegate>

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message completionBlock:(void (^)(NSUInteger buttonIndex, UIAlertView *alertView))block cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION;;

@end
