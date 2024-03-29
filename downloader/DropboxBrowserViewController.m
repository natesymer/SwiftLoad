//
//  DropboxBrowserViewController.m
//  SwiftLoad
//
//  Created by Nathaniel Symer on 3/30/13.
//  Copyright (c) 2013 Nathaniel Symer. All rights reserved.
//

#import "DropboxBrowserViewController.h"

static NSString *CellIdentifier = @"dbcell";

@interface NSString (dropbox_browser)

- (NSString *)fhs_normalize;

@end

@implementation NSString (dropbox_browser)

- (NSString *)fhs_normalize {
    if (![[self substringFromIndex:self.length-1]isEqualToString:@"/"]) {
        return [self.lowercaseString stringByAppendingString:@"/"];
    }
    return self.lowercaseString;
}

@end

@interface DropboxBrowserViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *theTableView;
@property (nonatomic, strong) UINavigationBar *navBar;
@property (nonatomic, strong) UIRefreshControl *refreshControl;

@property (nonatomic, strong) NSMutableArray *currentPathItems;

@property (nonatomic, assign) BOOL shouldPromptForLinkage;
@property (nonatomic, strong) NSString *cursor;

@property (nonatomic, assign) BOOL shouldMassInsert;

@property (nonatomic, strong) FMDatabase *database;
@property (nonatomic, strong) NSString *userID;

@property (nonatomic, assign) BOOL shouldStopLoading;

@end

@implementation DropboxBrowserViewController

- (void)loadView {
    [super loadView];
    
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(dropboxAuthenticationSucceeded) name:@"db_auth_success" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(dropboxAuthenticationFailed) name:@"db_auth_failure" object:nil];
    
    self.shouldPromptForLinkage = YES;
    
    CGRect screenBounds = [[UIScreen mainScreen]bounds];
    
    self.theTableView = [[UITableView alloc]initWithFrame:screenBounds style:UITableViewStylePlain];
    _theTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _theTableView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    _theTableView.dataSource = self;
    _theTableView.delegate = self;
    _theTableView.contentInset = UIEdgeInsetsMake(64, 0, 0, 0);
    _theTableView.scrollIndicatorInsets = _theTableView.contentInset;
    _theTableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    _theTableView.separatorInset = UIEdgeInsetsMake(0, 55, 0, 5);
    _theTableView.separatorColor = [UIColor colorWithWhite:0.9f alpha:1.0f];
    _theTableView.tableFooterView = [UIView new];
    [self.view addSubview:_theTableView];
    
    self.refreshControl = [[UIRefreshControl alloc]init];
    [_refreshControl addTarget:self action:@selector(refreshControlShouldRefresh:) forControlEvents:UIControlEventValueChanged];
    [_theTableView addSubview:_refreshControl];
    
    self.navBar = [[UINavigationBar alloc]initWithFrame:CGRectMake(0, 0, screenBounds.size.width, 64)];
    _navBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UINavigationItem *topItem = [[UINavigationItem alloc]initWithTitle:@"/"];
    topItem.leftBarButtonItem = [[UIBarButtonItem alloc]initWithImage:[UIImage imageNamed:@"ArrowLeft"] style:UIBarButtonItemStyleBordered target:self action:@selector(goBackDir)];
    topItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"Close" style:UIBarButtonItemStyleBordered target:self action:@selector(close)];
    topItem.leftBarButtonItem.enabled = NO;
    [_navBar pushNavigationItem:topItem animated:YES];
    [self.view addSubview:_navBar];
    _navBar.barTintColor = [UIColor colorWithRed:61.0f/255.0f green:154.0f/255.0f blue:232.0f/255.0f alpha:1.0f];

    self.currentPathItems = [NSMutableArray array];
    
    self.database = [FMDatabase databaseWithPath:[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0]stringByAppendingPathComponent:@"database.db"]];
    [_database open];
    [_database executeUpdate:@"CREATE TABLE IF NOT EXISTS dropbox_data (id INTEGER PRIMARY KEY AUTOINCREMENT, lowercasepath VARCHAR(255) DEFAULT NULL, filename VARCHAR(255) DEFAULT NULL, date INTEGER, size INTEGER, type INTEGER)"];
    [_database close];
}

- (void)dropboxAuthenticationFailed {
    [UIAlertView showAlertWithTitle:@"Dropbox Authentication Failed." andMessage:@"Swift failed to authenticate you with Dropbox. Please try again later."];
}

- (void)dropboxAuthenticationSucceeded {
    if ([[DBSession sharedSession]isLinked]) {
        [DropboxBrowserViewController clearDatabase];
        [_refreshControl beginRefreshing];
        [_theTableView setContentOffset:CGPointMake(0, -1*(_theTableView.contentInset.top)) animated:YES];
        [self loadUserID];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if ([[DBSession sharedSession]isLinked]) {
        [_refreshControl beginRefreshing];
        [_theTableView setContentOffset:CGPointMake(0, -1*(_theTableView.contentInset.top)) animated:YES];
        [self loadUserID];
    } else {
        if (_shouldPromptForLinkage) {
            self.shouldPromptForLinkage = NO;
            if (![[DBSession sharedSession]isLinked]) {
                [AppDelegate disableStyling];
                [[DBSession sharedSession]linkFromController:self];
            }
        } else {
            [self close];
        }
    }
}

+ (void)clearDatabase {
    FMDatabase *database = [FMDatabase databaseWithPath:[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0]stringByAppendingPathComponent:@"database.db"]];
    [database open];
    [database beginTransaction];
    [database executeUpdate:@"DROP TABLE dropbox_data"];
    [database executeUpdate:@"CREATE TABLE IF NOT EXISTS dropbox_data (id INTEGER PRIMARY KEY AUTOINCREMENT, lowercasepath VARCHAR(255) DEFAULT NULL, filename VARCHAR(255) DEFAULT NULL, date INTEGER, size INTEGER, type INTEGER)"];
    [database commit];
    [database close];
    [[NSFileManager defaultManager]removeItemAtPath:[kCachesDir stringByAppendingPathComponent:@"cursors.json"] error:nil];
}

- (void)batchInsert:(NSArray *)metadatas {
    [_database open];
    [_database beginTransaction];
    
    NSUInteger length = metadatas.count;
    
    // IMPORTANT INFO: the row constructor (multi-value insert command) has a hard limit of 1000 rows. But for some reason, Anything above 100 doesnt work... So I just do 25 to 50...
    
    for (int location = 0; location < length; location+=40) {
        @autoreleasepool {
            NSUInteger size = length-location;
            if (size > 40) {
                size = 40;
            }
            
            NSArray *array = [metadatas subarrayWithRange:NSMakeRange(location, size)];
            NSMutableString *query = [NSMutableString stringWithFormat:@"INSERT INTO dropbox_data (date,size,type,filename,lowercasepath) VALUES "];
            
            for (DBMetadata *item in array) {
                NSString *filename = item.filename;
                NSString *lowercasePath = item.path.stringByDeletingLastPathComponent.fhs_normalize;
                int type = item.isDirectory?2:1;
                int date = item.lastModifiedDate.timeIntervalSince1970;
                long long size = item.totalBytes;
                [query appendFormat:@"(%d,%lld,%d,\"%@\",\"%@\"),",date,size,type,filename,lowercasePath];
            }
            
            [query deleteCharactersInRange:NSMakeRange(query.length-1, 1)];
            [_database executeUpdate:query];
        }
    }

    [_database commit];
    [_database close];
}

- (void)loadContentsOfDirectory:(NSString *)string {
    [_currentPathItems removeAllObjects];
    [_database open];
    FMResultSet *s = [_database executeQuery:@"SELECT * FROM dropbox_data WHERE lowercasepath=? ORDER BY filename",string.lowercaseString.fhs_normalize];
    while ([s next]) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[NSFileName] = [s stringForColumn:@"filename"];
        dict[NSFileSize] = [NSNumber numberWithLongLong:[s intForColumn:@"size"]];
        dict[NSFileCreationDate] = [NSDate dateWithTimeIntervalSince1970:[s intForColumn:@"date"]];
        dict[NSFileType] = ([s intForColumn:@"type"] == 1)?NSFileTypeRegular:NSFileTypeDirectory;
        [_currentPathItems addObject:dict];
    }
    [s close];
    [_database close];
}

- (void)removeAllEntriesForCurrentUser {
    [_database open];
    [_database beginTransaction];
    [_database executeUpdate:@"DROP TABLE dropbox_data"];
    [_database executeUpdate:@"CREATE TABLE dropbox_data (id INTEGER PRIMARY KEY AUTOINCREMENT, lowercasepath VARCHAR(255) DEFAULT NULL, filename VARCHAR(255) DEFAULT NULL, date INTEGER, size INTEGER, type INTEGER)"];
    [_database commit];
    [_database close];
}

- (void)removeItemWithLowercasePath:(NSString *)path andFilename:(NSString *)filename {
    [_database open];
    [_database executeUpdate:@"DELETE FROM dropbox_data WHERE lowercasepath=? AND filename=?",path.lowercaseString.fhs_normalize,filename];
    [_database close];
}

- (void)addObjectToDatabase:(DBMetadata *)item withLowercasePath:(NSString *)lowercasePath {
    NSString *filename = item.filename;
    NSNumber *type = @(item.isDirectory?2:1);
    NSNumber *date = [NSNumber numberWithInt:item.lastModifiedDate.timeIntervalSince1970];
    NSNumber *size = [NSNumber numberWithLongLong:item.totalBytes];
    
    FMResultSet *s = [_database executeQuery:@"SELECT * FROM dropbox_data WHERE filename=? and lowercasepath=? LIMIT 1",filename,lowercasePath.fhs_normalize];
    BOOL shouldUpdate = [s next];
    [s close];
    
    if (shouldUpdate) {
        [_database executeUpdate:@"UPDATE dropbox_data SET date=?,size=? WHERE filename=?,lowercasepath=?",date,size,filename,lowercasePath.fhs_normalize];
    } else {
        [_database executeUpdate:@"INSERT INTO dropbox_data (date,size,type,filename,lowercasepath) VALUES (?,?,?,?,?)",date,size,type,filename,lowercasePath.fhs_normalize];
    }
}

- (void)refreshControlShouldRefresh:(UIRefreshControl *)control {
    [self loadUserID];
}

- (void)loadUserID {
    if (_userID.length == 0) {
        [[NetworkActivityController sharedController]show];
        __weak DropboxBrowserViewController *weakself = self;
        [DroppinBadassBlocks loadAccountInfoWithCompletionBlock:^(DBAccountInfo *info, NSError *error) {
            [[NetworkActivityController sharedController]hideIfPossible];
            if (error) {
                [UIAlertView showAlertWithTitle:[NSString stringWithFormat:@"Dropbox Error %ld",(long)error.code] andMessage:error.localizedDescription];
            } else {
                weakself.userID = info.userId;
                [weakself loadUserID];
            }
        }];
    } else {
        @autoreleasepool {
            NSString *filePath = [kCachesDir stringByAppendingPathComponent:@"cursors.json"];
            NSData *json = [NSData dataWithContentsOfFile:filePath];
            NSMutableDictionary *dict = [[NSFileManager defaultManager]fileExistsAtPath:filePath]?[NSJSONSerialization JSONObjectWithData:json options:NSJSONReadingMutableContainers error:nil]:[NSMutableDictionary dictionary];
            self.cursor = dict[_userID];
            [self updateFileListing];
        }
    }
}

- (void)saveCursor {
    @autoreleasepool {
        NSString *filePath = [kCachesDir stringByAppendingPathComponent:@"cursors.json"];
        NSData *jsonread = [NSData dataWithContentsOfFile:filePath];
        NSMutableDictionary *dict = [[NSFileManager defaultManager]fileExistsAtPath:filePath]?[NSJSONSerialization JSONObjectWithData:jsonread options:NSJSONReadingMutableContainers error:nil]:[NSMutableDictionary dictionary];
        dict[_userID] = _cursor;
        NSData *json = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONReadingMutableContainers error:nil];
        [json writeToFile:filePath atomically:YES];
    }
}

- (void)updateFileListing {
    [[NetworkActivityController sharedController]show];
    
    __weak DropboxBrowserViewController *weakself = self;
    
    [DroppinBadassBlocks loadDelta:_cursor withCompletionHandler:^(NSArray *entries, NSString *cursor, BOOL hasMore, BOOL shouldReset, NSError *error) {
        [[NetworkActivityController sharedController]hideIfPossible];
        if (error) {
            weakself.shouldMassInsert = NO;
        } else {
            
            if (weakself.shouldStopLoading) {
                return;
            }
            
            if (shouldReset) {
                //NSLog(@"Resetting");
                weakself.cursor = nil;
                [weakself.currentPathItems removeAllObjects];
                weakself.shouldMassInsert = YES;
                weakself.refreshControl.attributedTitle = [[NSAttributedString alloc]initWithString:@"Initial Load. Be patient..."];
                [weakself removeAllEntriesForCurrentUser];
            }
            
            weakself.cursor = cursor;
            
            NSMutableArray *array = [NSMutableArray array];
            
            if (!weakself.shouldMassInsert) {
                [weakself.database open];
            }
            
            for (DBDeltaEntry *entry in entries) {
                DBMetadata *item = entry.metadata;
                if (item) {
                    if (item.isDeleted) {
                        [weakself removeItemWithLowercasePath:entry.lowercasePath.stringByDeletingLastPathComponent andFilename:item.filename];
                    } else {
                        if (weakself.shouldMassInsert) {
                            [array addObject:item];
                        } else {
                            [weakself addObjectToDatabase:item withLowercasePath:entry.lowercasePath.stringByDeletingLastPathComponent]; // my lowercase path doesn't include the filename, Dropbox's does.
                        }
                    }
                }
            }
            
            if (!weakself.shouldMassInsert) {
                [_database close];
            }
            
            if (weakself.shouldMassInsert) {
                [weakself batchInsert:array];
            }

            if (hasMore) {
                //NSLog(@"Continuing");
                [weakself updateFileListing];
            } else {
                //NSLog(@"done");
                weakself.refreshControl.attributedTitle = nil;
                [weakself saveCursor];
                weakself.shouldMassInsert = NO;
                [weakself refreshStateWithAnimationStyle:UITableViewRowAnimationFade];
            }
        }
    }];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _currentPathItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    SwiftLoadCell *cell = (SwiftLoadCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[SwiftLoadCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    NSDictionary *fileDict = _currentPathItems[indexPath.row];
    NSString *filename = fileDict[NSFileName];
    
    cell.textLabel.text = filename;
    
    if ([(NSString *)fileDict[NSFileType] isEqualToString:(NSString *)NSFileTypeRegular]) {
        cell.imageView.image = [UIImage imageNamed:@"file_icon"];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"File, %@",[NSString fileSizePrettify:[fileDict[NSFileSize]intValue]]];
    } else {
        cell.detailTextLabel.text = @"Directory";
        cell.imageView.image = [UIImage imageNamed:@"folder_icon"];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    NSDictionary *fileDict = _currentPathItems[indexPath.row];
    
    NSString *filetype = (NSString *)fileDict[NSFileType];
    
    if ([filetype isEqualToString:(NSString *)NSFileTypeDirectory]) {
        _navBar.topItem.title = [_navBar.topItem.title stringByAppendingPathComponent:fileDict[NSFileName]];
        [self loadContentsOfDirectory:_navBar.topItem.title];
        [self refreshStateWithAnimationStyle:UITableViewRowAnimationLeft];
    } else {
        __weak DropboxBrowserViewController *weakself = self;
        UIActionSheet *actionSheet = [[UIActionSheet alloc]initWithTitle:fileDict[NSFileName] completionBlock:^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
            if (buttonIndex != actionSheet.cancelButtonIndex) {
                NSString *filePath = [weakself.navBar.topItem.title stringByAppendingPathComponent:fileDict[NSFileName]];
                
                if (buttonIndex == 0) {
                    [[TaskController sharedController]addTask:[DropboxDownload downloadWithPath:filePath]];
                } else if (buttonIndex == 1) {
                    [[TaskController sharedController]addTask:[DropboxLinkTask taskWithFilepath:filePath]];
                } else if (buttonIndex == 2 && filePath.isVideoFile) {
                    [DroppinBadassBlocks loadStreamableURLForFile:filePath andCompletionBlock:^(NSURL *url, NSString *path, NSError *error) {
                        if (!error) {
                            [weakself presentViewController:[MoviePlayerViewController moviePlayerWithStreamingURL:url] animated:YES completion:nil];
                        } else {
                            [UIAlertView showAlertWithTitle:@"Failed to Stream File" andMessage:error.localizedDescription];
                        }
                    }];
                }
            }
        } cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:@"Download", @"Get Link", nil];
        
        if ([fileDict[NSFileName] isVideoFile]) {
            [actionSheet addButtonWithTitle:@"Stream"];
        }
        
        [actionSheet addButtonWithTitle:@"Cancel"];
        actionSheet.cancelButtonIndex = actionSheet.numberOfButtons-1;
        
        actionSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
        [actionSheet showInView:self.view];
    }
    
    [_theTableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (void)goBackDir {
    _navBar.topItem.title = [_navBar.topItem.title stringByDeletingLastPathComponent];
    [self loadContentsOfDirectory:[_navBar.topItem.title fhs_normalize]];
    [self refreshStateWithAnimationStyle:UITableViewRowAnimationRight];
}

- (void)refreshStateWithAnimationStyle:(UITableViewRowAnimation)animation {
    [self loadContentsOfDirectory:[_navBar.topItem.title fhs_normalize]];
    [_theTableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:animation];
    _navBar.topItem.leftBarButtonItem.enabled = (_navBar.topItem.title.length > 1);
    [_refreshControl endRefreshing];
}

- (void)close {
    self.shouldStopLoading = YES;
    int count = [[DroppinBadassBlocks sharedInstance]cancelAllMiscRequests];
    
    for (int i = 0; i < count; i++) {
        [[NetworkActivityController sharedController]hideIfPossible];
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return (toInterfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

@end
