//
//  pictureView.m
//  SwiftLoad
//
//  Created by Nathaniel Symer on 10/27/11.
//  Copyright 2011 Nathaniel Symer. All rights reserved.
//

#import "PictureViewController.h"

@interface PictureViewController ()

@property (nonatomic, strong) ZoomingImageView *zoomingImageView;
@property (nonatomic, strong) UIBarButtonItem *prevImg;
@property (nonatomic, strong) UIBarButtonItem *nextImg;
@property (nonatomic, strong) UINavigationBar *navBar;
@property (nonatomic, strong) UIToolbar *toolBar;

@property (nonatomic, assign) int imageNumber;

@end

@implementation PictureViewController

- (void)loadView {
    [super loadView];
    CGRect screenBounds = [[UIScreen mainScreen]bounds];
    
    self.zoomingImageView = [[ZoomingImageView alloc]initWithFrame:screenBounds];
    _zoomingImageView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    _zoomingImageView.decelerationRate = UIScrollViewDecelerationRateFast;
    [self.view addSubview:_zoomingImageView];
    
    self.navBar = [[UINavigationBar alloc]initWithFrame:CGRectMake(0, 0, screenBounds.size.width, 64)];
    _navBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UINavigationItem *topItem = [[UINavigationItem alloc]initWithTitle:self.openFile.lastPathComponent];
    topItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(showActionSheet:)];
    topItem.leftBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"Close" style:UIBarButtonItemStyleBordered target:self action:@selector(close)];
    [_navBar pushNavigationItem:topItem animated:NO];
    [self.view addSubview:_navBar];
    
    self.toolBar = [[UIToolbar alloc]initWithFrame:CGRectMake(0, screenBounds.size.height-44, screenBounds.size.width, 44)];
    _toolBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    
    UIBarButtonItem *space = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    self.nextImg = [[UIBarButtonItem alloc]initWithImage:[UIImage imageNamed:@"ArrowRight"] style:UIBarButtonItemStylePlain target:self action:@selector(nextImage)];
    self.prevImg = [[UIBarButtonItem alloc]initWithImage:[UIImage imageNamed:@"ArrowLeft"] style:UIBarButtonItemStylePlain target:self action:@selector(previousImage)];
    
    [self.view addSubview:_toolBar];
    
    _toolBar.items = @[space,_prevImg,space,_nextImg,space];
    
    UITapGestureRecognizer *tt = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(imageViewWasDoubleTapped:)];
    [tt setNumberOfTapsRequired:2];
    [tt setNumberOfTouchesRequired:1];
    [_zoomingImageView addGestureRecognizer:tt];
    
    UITapGestureRecognizer *t = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(imageViewWasSingleTapped:)];
    [t setNumberOfTapsRequired:1];
    [t setNumberOfTouchesRequired:1];
    [_zoomingImageView addGestureRecognizer:t];

    [t requireGestureRecognizerToFail:tt];
    
    NSArray *imageFiles = [self imageFiles];
    
    self.imageNumber = [imageFiles indexOfObject:self.openFile.lastPathComponent];
    
    if (imageFiles.count == 1) {
        [_nextImg setEnabled:NO];
        [_prevImg setEnabled:NO];
    }
    
    if (_imageNumber == 0) {
        [_prevImg setEnabled:NO];
    }
    
    if (_imageNumber == imageFiles.count-1) {
        [_nextImg setEnabled:NO];
    }

    _zoomingImageView.image = [UIImage imageWithContentsOfFile:self.openFile];
}

- (NSArray *)imageFiles {
    NSArray *extensions = @[@"tiff", @"tif", @"jpg", @"jpeg", @"gif", @"png", @"bmp", @"BMPf", @"ico", @"cur", @"xbm"];
    NSArray *dirContents = [[NSFileManager defaultManager]contentsOfDirectoryAtPath:kAppDelegate.managerCurrentDir error:nil];
    return [[dirContents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension.lowercaseString IN %@", extensions]]sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (void)addToTheRoll {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            UIImage *image = [UIImage imageWithContentsOfFile:self.openFile];
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
        }
    });
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:^{
        [[UIApplication sharedApplication]setStatusBarHidden:NO];
    }];
}

- (void)actionSheet:(UIActionSheet *)actionSheet selectedIndex:(NSUInteger)buttonIndex {
    NSString *title = [actionSheet buttonTitleAtIndex:buttonIndex];
    
    if ([title isEqualToString:kActionButtonNameEmail]) {
        [kAppDelegate sendFileInEmail:self.openFile];
    } else if ([title isEqualToString:kActionButtonNameP2P]) {
        [[P2PManager shared]sendFileAtPath:self.openFile];
    } else if ([title isEqualToString:kActionButtonNameDBUpload]) {
        [[TaskController sharedController]addTask:[DropboxUpload uploadWithFile:self.openFile]];
    } else if ([title isEqualToString:kActionButtonNamePrint]) {
        [kAppDelegate printFile:self.openFile];
    } else if ([title isEqualToString:kActionButtonNameSavePhotoLibrary]) {
        if (self.openFile.isImageFile) {
            [self addToTheRoll];
        } else {
            NSString *message = [NSString stringWithFormat:@"Unable to save %@ to the camera roll.",self.openFile.lastPathComponent];
            [UIAlertView showAlertWithTitle:@"Import Failure" andMessage:message];
        }
    }
}

// Action in reverse is Noitca
- (void)showActionSheet:(id)sender {
    [self showActionSheetFromBarButtonItem:(UIBarButtonItem *)sender withButtonTitles:@[kActionButtonNameEmail, kActionButtonNameP2P, kActionButtonNameDBUpload, kActionButtonNamePrint, kActionButtonNameSavePhotoLibrary]];
}

- (void)nextImage {
    @autoreleasepool {
        _prevImg.enabled = YES;
        self.imageNumber += 1;
        
        NSArray *imageFiles = [self imageFiles];
        
        NSString *newImageName = imageFiles[_imageNumber];
        _navBar.topItem.title = newImageName;
        
        if (imageFiles.count-1 == _imageNumber) {
            [_nextImg setEnabled:NO];
        }
        
        NSString *newImagePath = [kAppDelegate.managerCurrentDir stringByAppendingPathComponent:newImageName];
        self.openFile = newImagePath;
        _zoomingImageView.image = [UIImage imageWithContentsOfFile:newImagePath];
    }
}

- (void)previousImage {
    _nextImg.enabled = YES;
    self.imageNumber -= 1;
    
    NSArray *imageFiles = [self imageFiles];

    if (_imageNumber == 0) {
        [_prevImg setEnabled:NO];
    }

    NSString *newImageName = imageFiles[_imageNumber];
    _navBar.topItem.title = newImageName;
    
    NSString *newImagePath = [kAppDelegate.managerCurrentDir stringByAppendingPathComponent:newImageName];
    self.openFile = newImagePath;
    _zoomingImageView.image = [UIImage imageWithContentsOfFile:newImagePath];
}

- (void)imageViewWasSingleTapped:(UIGestureRecognizer *)rec {
    __weak PictureViewController *weakself = self;
    [UIView animateWithDuration:0.2f animations:^{
        weakself.navBar.alpha = (weakself.navBar.alpha == 1.0f)?0.0f:1.0f;
        weakself.toolBar.alpha = (weakself.toolBar.alpha == 1.0f)?0.0f:1.0f;
        
        UIView *statusBar = [[UIApplication sharedApplication]valueForKey:@"statusBar"];
        statusBar.alpha = (statusBar.alpha == 1.0f)?0.0f:1.0f;
        
        weakself.view.backgroundColor = (weakself.view.backgroundColor == [UIColor blackColor])?[UIColor whiteColor]:[UIColor blackColor];
    }];
}

- (void)imageViewWasDoubleTapped:(UIGestureRecognizer *)rec {
    if (_zoomingImageView.zoomScale > _zoomingImageView.minimumZoomScale) {
        [_zoomingImageView zoomOut];
    } else {
        [_zoomingImageView zoomToPoint:[rec locationInView:self.view] withScale:_zoomingImageView.maximumZoomScale animated:YES];
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [_zoomingImageView resetImage];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

@end
