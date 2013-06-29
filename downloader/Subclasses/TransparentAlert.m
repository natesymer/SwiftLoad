//
//  TransparentAlert.m
//  SwiftLoad
//
//  Created by Nathaniel Symer on 6/21/13.
//  Copyright (c) 2013 Nathaniel Symer. All rights reserved.
//

#import "TransparentAlert.h"

@implementation TransparentAlert

- (UIImage *)drawButtonImage {
    UIGraphicsBeginImageContext(CGSizeMake(5, 37));
    CGContextRef context = UIGraphicsGetCurrentContext();
    UIGraphicsPushContext(context);
    
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 5, 37) cornerRadius:0];
    [[UIColor colorWithWhite:0.0 alpha:0.8]setFill];
    
    CGContextAddPath(context, path.CGPath);
    CGContextFillPath(context);
    
    UIGraphicsPopContext();
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (UIImage *)drawButtonImagePressed {
    UIGraphicsBeginImageContext(CGSizeMake(5, 37));
    CGContextRef context = UIGraphicsGetCurrentContext();
    UIGraphicsPushContext(context);
    
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 5, 37) cornerRadius:0];
    [[UIColor colorWithWhite:1.0 alpha:0.8]setFill];
    
    CGContextAddPath(context, path.CGPath);
    CGContextFillPath(context);
    
    UIGraphicsPopContext();
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)layoutSubviews {
    self.backgroundColor = [UIColor colorWithWhite:0.6 alpha:0.85];
    
    self.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:0.85].CGColor;
    self.layer.borderWidth = 5;
    self.layer.cornerRadius = 5;
    
    for (UIView *subview in self.subviews) {
        
        if ([subview isKindOfClass:NSClassFromString(@"UIAlertTextView")]) {
            [subview setHidden:YES];
        }
		
		if ([subview isMemberOfClass:[UIImageView class]]) {
            [subview setHidden:YES];
		}
        
        if ([subview isKindOfClass:[UIControl class]] && ![subview isKindOfClass:[UITextField class]]) {
            
            subview.frame = CGRectMake(subview.frame.origin.x+2.5, subview.frame.origin.y+5, subview.frame.size.width-5, 37);
            
            subview.layer.cornerRadius = 5;

            UIImage *buttonImage = [[self drawButtonImage]resizableImageWithCapInsets:UIEdgeInsetsMake(0, 5, 0, 5)];
            [(UIButton *)subview setBackgroundImage:buttonImage forState:UIControlStateNormal];
            
            UIImage *buttonImagePressed = [[self drawButtonImagePressed]resizableImageWithCapInsets:UIEdgeInsetsMake(0, 5, 0, 5)];
            [(UIButton *)subview setBackgroundImage:buttonImagePressed forState:UIControlStateHighlighted];
        }
        
		if ([subview isKindOfClass:[UILabel class]]) {
			UILabel *label = (UILabel*)subview;
            label.textColor = [UIColor blackColor];
            label.shadowOffset = CGSizeZero;
		}
	}
}

@end