//
//  SwiftDisclosureCell.m
//  Swift
//
//  Created by Nathaniel Symer on 9/21/13.
//  Copyright (c) 2013 Nathaniel Symer. All rights reserved.
//

#import "SwiftDisclosureCell.h"

@implementation SwiftDisclosureCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.disclosureButton = [DisclosureButton button];
        [self.contentView addSubview:_disclosureButton];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    int rowHeight = self.frame.size.height;
    float maxWidth = self.bounds.size.width-rowHeight-self.textLabel.frame.origin.x;
    
    if (self.detailTextLabel.bounds.size.width > maxWidth) {
        CGRect detail = self.detailTextLabel.frame;
        detail.size.width = maxWidth;
        self.detailTextLabel.frame = detail;
    }
    
    if (self.textLabel.bounds.size.width > maxWidth) {
        CGRect text = self.textLabel.frame;
        text.size.width = maxWidth;
        self.textLabel.frame = text;
    }
    
    _disclosureButton.frame = CGRectMake(self.bounds.size.width-rowHeight, 0, rowHeight, rowHeight);
}

@end