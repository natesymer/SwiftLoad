//
//  Hamburger.m
//  SwiftLoad
//
//  Created by Nathaniel Symer on 7/13/13.
//  Copyright (c) 2013 Nathaniel Symer. All rights reserved.
//

#import "Hamburger.h"
#import "HamburgerCell.h"

NSString * const kHamburgerTaskUpdateNotification = @"kHamburgerTaskUpdateNotification";
static NSString *kCellIdentifierHamburger = @"hamburgertext";
static NSString * const kCellIdentifierHamburgerSeparator = @"hamburgersep";
static NSString * const kCellIdentifierHamburgerTask = @"hamburgertask";

@interface HamburgerView : UIView <UITableViewDataSource, UITableViewDelegate>

+ (HamburgerView *)view;

@property (nonatomic, weak) id<HamburgerViewDelegate> delegate;
@property (nonatomic, strong) UITableView *theTableView;
@property (nonatomic, weak) HamburgerButtonItem *item;

@end

@interface HamburgerButtonItem ()

@property (nonatomic, strong) HamburgerView *hamburgerView;
@property (nonatomic, strong) UIButton *hideButton;
@property (nonatomic, weak) UIView *viewToMove;
@property (nonatomic, weak) UIColor *originalBackgroundColor;
@property (nonatomic, assign) BOOL originalOpacity;

@end

@implementation HamburgerButtonItem

+ (HamburgerButtonItem *)itemWithView:(UIView *)viewToMove {
    HamburgerButtonItem *item = [[HamburgerButtonItem alloc]initWithImage:[UIImage imageNamed:@"hamburger"] style:UIBarButtonItemStyleBordered target:nil action:nil];
    [item setTarget:item];
    item.action = @selector(toggleState);
    item.hamburgerView = [HamburgerView view];
    item.hamburgerView.item = item;
    item.hamburgerView.alpha = 0.0f;
    item.viewToMove = viewToMove;
    item.viewToMove.layer.shadowPath = [UIBezierPath bezierPathWithRect:item.viewToMove.bounds].CGPath;
    item.viewToMove.layer.shadowColor = [UIColor blackColor].CGColor;
    item.hideButton = [UIButton buttonWithType:UIButtonTypeCustom];
    item.hideButton.frame = item.viewToMove.bounds;
    [item.hideButton addTarget:item action:@selector(hide) forControlEvents:UIControlEventTouchDown];
    return item;
}

- (void)setDelegate:(id<HamburgerViewDelegate>)delegate {
    [_hamburgerView setDelegate:delegate];
}

- (void)showShadow {
    _viewToMove.layer.shadowOffset = CGSizeMake(-3, 0);
}

- (void)clearShadow {
    _viewToMove.layer.shadowOffset = CGSizeZero;
}

- (void)hide {
    [UIView animateWithDuration:0.3f animations:^{
        _viewToMove.layer.shadowOpacity = 0.0f;
        _hamburgerView.alpha = 0.0f;
        _viewToMove.frame = CGRectMake(0, _viewToMove.frame.origin.y, _viewToMove.frame.size.width, _viewToMove.frame.size.height);
    } completion:^(BOOL finished) {
        [_hamburgerView removeFromSuperview];
        [_hideButton removeFromSuperview];
        [_viewToMove setBackgroundColor:_originalBackgroundColor];
        _viewToMove.layer.shadowOffset = CGSizeZero;
        _viewToMove.layer.shouldRasterize = NO;
    }];
}

- (void)show {
    UIWindow *mainWindow = [kAppDelegate window];
    [mainWindow insertSubview:_hamburgerView belowSubview:_viewToMove];
    [_viewToMove addSubview:_hideButton];
    self.originalBackgroundColor = _viewToMove.backgroundColor;
    [_viewToMove setBackgroundColor:mainWindow.backgroundColor];
    _viewToMove.layer.shadowOffset = CGSizeMake(-3, 0);
    _viewToMove.layer.shouldRasterize = YES;
    _viewToMove.layer.rasterizationScale = [UIScreen mainScreen].scale;
    [UIView animateWithDuration:0.3f animations:^{
        _viewToMove.layer.shadowOpacity = 0.25f;
        _hamburgerView.alpha = 1.0f;
        _viewToMove.frame = CGRectMake(250, _viewToMove.frame.origin.y, _viewToMove.frame.size.width, _viewToMove.frame.size.height);
    }];
}

- (void)toggleState {
    if (_hamburgerView.superview) {
        [self hide];
    } else {
        [self show];
    }
}

- (void)dealloc {
    [self setViewToMove:nil];
}

@end

@implementation HamburgerView

+ (HamburgerView *)view {
    return [[[self class]alloc]init];
}

- (id)init {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(tasksChanged) name:kHamburgerTaskUpdateNotification object:nil];
        self.userInteractionEnabled = YES;
        self.backgroundColor = bgcolor;
        self.frame = CGRectMake(0, 20, 250, [[UIScreen mainScreen]applicationFrame].size.height);
        self.opaque = YES;
        self.theTableView = [[UITableView alloc]initWithFrame:self.bounds style:UITableViewStylePlain];
        _theTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _theTableView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        _theTableView.backgroundColor = bgcolor;
        _theTableView.rowHeight = 44;
        _theTableView.dataSource = self;
        _theTableView.delegate = self;
        _theTableView.opaque = YES;
        [self addSubview:_theTableView];
    }
    return self;
}

- (void)tasksChanged {
    [_theTableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (section == 0)?5:[[TaskController sharedController]numberOfTasks];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return ([[TaskController sharedController]numberOfTasks] > 0)?2:1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    int row = indexPath.row;
    
    if (indexPath.section == 0) {
        HamburgerCell *cell = (HamburgerCell *)[tableView dequeueReusableCellWithIdentifier:kCellIdentifierHamburger];
        
        if (cell == nil) {
            cell = [[HamburgerCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellIdentifierHamburger];
            cell.backgroundColor = self.backgroundColor;
        }
        
        cell.isFirstCell = (indexPath.row == 0);
        
        if (row == 0) {
            cell.textLabel.text = @"Download URL";
        } else if (row == 1) {
            cell.textLabel.text = @"WebDAV Server";
        } else if (row == 2) {
            cell.textLabel.text = @"Browse Dropbox";
        } else if (row == 3) {
            cell.textLabel.text = @"Browse SFTP";
        } else if (row == 4) {
            cell.textLabel.text = @"Settings";
        }
        
        [cell setNeedsDisplay];
        
        return cell;
    } else if (indexPath.section == 1) {
        TaskCell *cell = (TaskCell *)[_theTableView dequeueReusableCellWithIdentifier:kCellIdentifierHamburgerTask];
        
        if (!cell) {
            cell = [[TaskCell alloc]initWithReuseIdentifier:kCellIdentifierHamburgerTask];
        }
        
        Task *task = [[TaskController sharedController]taskAtIndex:row];
        task.delegate = cell;
        [cell setText:[task.name percentSanitize]];
        [cell setDetailText:[task verb]];
        
        return cell;
    }
    
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 1) {
        return ([[TaskController sharedController]numberOfTasks] > 0)?10:0;
    }
    return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 1 && [[TaskController sharedController]numberOfTasks] > 0) {
        DashedLineView *dashedLineView = [[DashedLineView alloc]initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 5)];
        return dashedLineView;
    }
    
    return nil;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) {
        return nil;
    }
    
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_delegate && [_delegate respondsToSelector:@selector(hamburgerCellWasSelectedAtIndex:)]) {
        [_item hide];
        [_delegate hamburgerCellWasSelectedAtIndex:indexPath.row];
    }
    [_theTableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return @"Cancel";
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1 && indexPath.row < [[TaskController sharedController]numberOfTasks]) {
        return [[[TaskController sharedController]taskAtIndex:indexPath.row]canStop];
    }
    return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [[TaskController sharedController]removeTaskAtIndex:indexPath.row];
        [_theTableView beginUpdates];
        [_theTableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        
        if ([[TaskController sharedController]numberOfTasks] == 0) {
            [_theTableView deleteSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        [_theTableView endUpdates];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _theTableView.frame = self.bounds;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

@end

