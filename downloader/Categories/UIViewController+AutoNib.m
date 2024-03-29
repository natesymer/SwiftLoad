//
//  UIViewController+AutoNib.m
//  SwiftLoad
//
//  Created by Nathaniel Symer on 10/29/12.
//  Copyright (c) 2012 Nathaniel Symer. All rights reserved.
//

#import "UIViewController+AutoNib.h"

@implementation UIViewController (AutoNib)

- (instancetype)initWithAutoNib {
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    NSString *class = NSStringFromClass([self class]);
    self = [self initWithNibName:isPad?[class stringByAppendingString:@"~iPad"]:class bundle:nil];
    return self;
}

+ (instancetype)viewController {
    UIViewController *vc = [[[self class]alloc]init];
    vc.view.backgroundColor = [UIColor clearColor];
    vc.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
    return vc;
}

+ (instancetype)viewControllerWhite {
    UIViewController *vc = [[[self class]alloc]init];
    vc.view.backgroundColor = [UIColor whiteColor];
    return vc;
}

+ (instancetype)viewControllerNib {
    return [[[self class]alloc]initWithAutoNib];
}

+ (instancetype)topViewController {
    UIViewController *topController = [([[UIApplication sharedApplication]windows][0]) rootViewController]; // [[UIApplication sharedApplication]keyWindow] returns a UIActionWindow when a UIAlertView or UIActionSheet is shown, not your app's window
    
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    return topController;
}

@end
