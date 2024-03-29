//
//  UIImage+Additions.m
//  SwiftLoad
//
//  Created by Nathaniel Symer on 7/12/13.
//  Copyright (c) 2013 Nathaniel Symer. All rights reserved.
//

#import "UIImage+Additions.h"

@implementation UIImage (Additions)

UIColor * RGBA(float red, float green, float blue, float alpha) {
    return [UIColor colorWithRed:red/255.0f green:green/255.0f blue:blue/255.0f alpha:alpha];
}

UIColor * RGB(float red, float green, float blue) {
    return RGBA(red, green, blue, 1.0f);
}

- (UIImage *)imageFilledWith:(UIColor *)color {
    CGImageRef cgimage = self.CGImage;
    CGRect imageRect = CGRectMake(0, 0, CGImageGetWidth(cgimage), CGImageGetHeight(cgimage));
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(nil, imageRect.size.width, imageRect.size.height, 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);
    
    CGContextClipToMask(context, imageRect, cgimage);
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillRect(context, imageRect);
    
    CGImageRef newCGImage = CGBitmapContextCreateImage(context);
    UIImage *newImage = [UIImage imageWithCGImage:newCGImage scale:self.scale orientation:self.imageOrientation];
    CGContextRelease(context);
    CGImageRelease(newCGImage);
    CGColorSpaceRelease(colorSpace);
    return newImage;
}

@end

@implementation UIColor (Additions)

- (UIImage *)imageWithSize:(CGSize)size {
    CGRect rect = CGRectZero;
    rect.size = size;
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, self.CGColor);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@end
