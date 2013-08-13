//
//  TransparentTextField.m
//  Swift
//
//  Created by Nathaniel Symer on 8/13/13.
//  Copyright (c) 2013 Nathaniel Symer. All rights reserved.
//

#import "TransparentTextField.h"

@implementation TransparentTextField

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        self.borderStyle = UITextBorderStyleNone;
        self.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.85];
        self.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:0.85].CGColor;
        //self.layer.borderWidth = 1.5f;
        self.layer.cornerRadius = 5;
        self.opaque = NO;
    }
    return self;
}

@end