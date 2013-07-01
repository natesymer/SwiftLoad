//
//  CustomSlider.m
//  SwiftLoad
//
//  Created by Nate Symer on 5/25/12.
//  Copyright (c) 2012 Nathaniel Symer. All rights reserved.
//

#import "CustomSlider.h"

#define LIGHT_BLUE [UIColor colorWithRed:105.0f/255.0f green:179.0f/255.0f blue:216.0f/255.0f alpha:1.0].CGColor
#define DARK_BLUE [UIColor colorWithRed:21.0/255.0 green:92.0/255.0 blue:136.0/255.0 alpha:1.0].CGColor

void drawLinearGradient(CGContextRef context, CGRect rect, CGColorRef startColor, CGColorRef  endColor);
void drawGlossAndGradient(CGContextRef context, CGRect rect, CGColorRef startColor, CGColorRef endColor);

void drawLinearGradient(CGContextRef context, CGRect rect, CGColorRef startColor, CGColorRef  endColor) {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[] = { 0.0, 1.0 };
    
    NSArray *colors = [NSArray arrayWithObjects:(id)startColor, (id)endColor, nil];
    
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (CFArrayRef) colors, locations);
    
    CGPoint startPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMinY(rect));
    CGPoint endPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMaxY(rect));
    
    CGContextSaveGState(context);
    CGContextAddRect(context, rect);
    CGContextClip(context);
    CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
    CGContextRestoreGState(context);
    
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}

void drawGlossAndGradient(CGContextRef context, CGRect rect, CGColorRef startColor, CGColorRef endColor) {
    drawLinearGradient(context, rect, startColor, endColor);
    
    CGColorRef glossColor1 = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.35].CGColor;
    CGColorRef glossColor2 = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.1].CGColor;
    
    CGRect topHalf = CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height/2);
    
    drawLinearGradient(context, topHalf, glossColor1, glossColor2);
}

@implementation CustomSlider

- (void)setupGraphics {
    [self setMinimumTrackTintColor:[UIColor colorWithPatternImage:[self maximumImage]]];
    [self setMaximumTrackTintColor:[UIColor colorWithPatternImage:[self minimumImage]]];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupGraphics];
    }
    return self;
}

- (UIImage *)minimumImage {
    UIGraphicsBeginImageContext(CGSizeMake(1, self.bounds.size.height));
    CGContextRef context = UIGraphicsGetCurrentContext();		
    UIGraphicsPushContext(context);

    CGColorRef shadowColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:0.5].CGColor;
    
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, CGSizeMake(0, 2), 3.0, shadowColor);
    CGContextSetFillColorWithColor(context, DARK_BLUE);
    CGContextFillRect(context, self.bounds);
    CGContextRestoreGState(context);
    
    drawGlossAndGradient(context, self.bounds, LIGHT_BLUE, DARK_BLUE);
    
    UIGraphicsPopContext();								
    
    UIImage *outputImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return outputImage;
}

- (UIImage *)maximumImage {
    UIGraphicsBeginImageContext(CGSizeMake(1, self.bounds.size.height));
    CGContextRef context = UIGraphicsGetCurrentContext();		
    UIGraphicsPushContext(context);	   

    CGColorRef shadowColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:0.5].CGColor;
    
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, CGSizeMake(0, 2), 3.0, shadowColor);
    CGContextSetFillColorWithColor(context, LIGHT_BLUE);
    CGContextFillRect(context, self.bounds);
    CGContextRestoreGState(context);
    
    drawGlossAndGradient(context, self.bounds, DARK_BLUE, LIGHT_BLUE);
    
    UIGraphicsPopContext();								
    
    UIImage *outputImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return outputImage;
}

- (void)awakeFromNib {
    [self setupGraphics];
}

@end
