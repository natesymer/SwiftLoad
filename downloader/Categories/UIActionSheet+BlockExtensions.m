//
//  UIActionSheet+BlockExtensions.m
//
//  Created by Tom Fewster on 25/10/2011.
//

#import "UIActionSheet+BlockExtensions.h"
#import <objc/runtime.h>

@implementation UIActionSheet (BlockExtensions)

- (instancetype)initWithTitle:(NSString *)title completionBlock:(void (^)(NSUInteger buttonIndex, UIActionSheet *actionSheet))block cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ... {
	
    self = [self initWithTitle:title delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    
	if (self) {
        objc_setAssociatedObject(self, "blockCallback", [block copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
		if (destructiveButtonTitle) {
			[self addButtonWithTitle:destructiveButtonTitle];
			self.destructiveButtonIndex = [self numberOfButtons] - 1;
		}
		
		id eachObject;
		va_list argumentList;
		if (otherButtonTitles) {
			[self addButtonWithTitle:otherButtonTitles];
			va_start(argumentList, otherButtonTitles);
			while ((eachObject = va_arg(argumentList, id))) {
				[self addButtonWithTitle:eachObject];
			}
			va_end(argumentList);
		}
		
		if (cancelButtonTitle) {
			[self addButtonWithTitle:cancelButtonTitle];
			self.cancelButtonIndex = [self numberOfButtons] - 1;
		}
	}	
	return self;
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	void (^block)(NSUInteger buttonIndex, UIActionSheet *actionSheet) = objc_getAssociatedObject(self, "blockCallback");
    
    if (block) {
        block(buttonIndex, self);
    }
}

@end
