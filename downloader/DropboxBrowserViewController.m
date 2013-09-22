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
    if (![[self substringFromIndex:1]isEqualToString:@"/"]) {
        return [[self lowercaseString]stringByAppendingString:@"/"];
    }
    return [self lowercaseString];
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
    BOOL iPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    
    self.navBar = [[UINavigationBar alloc]initWithFrame:CGRectMake(0, 0, screenBounds.size.width, 64)];
    _navBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UINavigationItem *topItem = [[UINavigationItem alloc]initWithTitle:@"/"];
    topItem.leftBarButtonItem = [[UIBarButtonItem alloc]initWithImage:[UIImage imageNamed:@"ArrowLeft"] style:UIBarButtonItemStyleBordered target:self action:@selector(goBackDir)];
    topItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"Close" style:UIBarButtonItemStyleBordered target:self action:@selector(close)];
    [_navBar pushNavigationItem:topItem animated:YES];
    [self.view addSubview:_navBar];
    
    self.theTableView = [[UITableView alloc]initWithFrame:screenBounds style:UITableViewStylePlain];
    _theTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _theTableView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    _theTableView.rowHeight = iPad?60:44;
    _theTableView.dataSource = self;
    _theTableView.delegate = self;
    _theTableView.contentInset = UIEdgeInsetsMake(64, 0, 0, 0);
    _theTableView.scrollIndicatorInsets = _theTableView.contentInset;
    [self.view addSubview:_theTableView];
    
    [self.view bringSubviewToFront:_navBar];
    
    self.refreshControl = [[UIRefreshControl alloc]init];
    [_refreshControl addTarget:self action:@selector(refreshControlShouldRefresh:) forControlEvents:UIControlEventValueChanged];
    [_theTableView addSubview:_refreshControl];

    self.currentPathItems = [NSMutableArray array];
    
    self.database = [FMDatabase databaseWithPath:[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0]stringByAppendingPathComponent:@"database.db"]];
    [_database open];
    [_database executeUpdate:@"CREATE TABLE IF NOT EXISTS dropbox_data (id INTEGER PRIMARY KEY AUTOINCREMENT, lowercasepath VARCHAR(255) DEFAULT NULL, filename VARCHAR(255) DEFAULT NULL, date INTEGER, size INTEGER, type INTEGER)"];
    [_database close];
    
    _navBar.topItem.leftBarButtonItem.enabled = NO;
}

- (void)dropboxAuthenticationFailed {
    [UIAlertView showAlertWithTitle:@"Dropbox Authentication Failed." andMessage:@"Swift failed to authenticate you with Dropbox. Please try again later."];
}

- (void)dropboxAuthenticationSucceeded {
    if ([[DBSession sharedSession]isLinked]) {
        [_refreshControl beginRefreshing];
        [self loadUserID];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if ([[DBSession sharedSession]isLinked]) {
        [_refreshControl beginRefreshing];
        [_theTableView setContentOffset:CGPointMake(0, -1*(_theTableView.contentInset.top)) animated:YES];
        [self loadUserID];
    } else if (_shouldPromptForLinkage) {
        self.shouldPromptForLinkage = NO;
        if (![[DBSession sharedSession]isLinked]) {
            [[DBSession sharedSession]linkFromController:self];
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
    
    int length = metadatas.count;
    
    // IMPORTANT INFO: the row constructor (multi-value insert command) has a hard limit of 1000 rows. But for some reason, Anything above 100 doesnt work... So I just do 25 to 50...
    
    for (int location = 0; location < length; location+=50) {
        unsigned int size = length-location;
        if (size > 50)  {
            size = 50;
        }
        
        NSArray *array = [metadatas subarrayWithRange:NSMakeRange(location, size)];
        NSMutableString *query = [NSMutableString stringWithFormat:@"INSERT INTO dropbox_data (date,size,type,filename,lowercasepath) VALUES "];

        for (DBMetadata *item in array) {
            NSString *filename = item.filename;
            NSString *lowercasePath = [[item.path stringByDeletingLastPathComponent]fhs_normalize];
            int type = item.isDirectory?2:1;
            int date = item.lastModifiedDate.timeIntervalSince1970;
            int size = item.totalBytes;
            [query appendFormat:@"(%d,%d,%d,\"%@\",\"%@\"),",date,size,type,filename,lowercasePath];
        }
        
        [query deleteCharactersInRange:NSMakeRange(query.length-1, 1)];
        [_database executeUpdate:query];
    }

    [_database commit];
    [_database close];
}

- (void)loadContentsOfDirectory:(NSString *)string {
    [_currentPathItems removeAllObjects];
    [_database open];
    FMResultSet *s = [_database executeQuery:@"SELECT * FROM dropbox_data where lowercasepath=? ORDER BY filename",[string lowercaseString]];
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

- (void)removeItemWithLowercasePath:(NSString *)path {
    [_database open];
    [_database executeUpdate:@"DELETE FROM dropbox_data WHERE lowercasepath=?",[path lowercaseString]];
    [_database close];
}

- (void)addObjectToDatabase:(DBMetadata *)item withLowercasePath:(NSString *)lowercasePath {
    NSString *filename = item.filename;
    NSNumber *type = @(item.isDirectory?2:1);
    NSNumber *date = [NSNumber numberWithInt:item.lastModifiedDate.timeIntervalSince1970];
    NSNumber *size = [NSNumber numberWithInt:item.totalBytes];
    
    FMResultSet *s = [_database executeQuery:@"SELECT type FROM dropbox_data WHERE filename=? and lowercasepath=? LIMIT 1",filename,lowercasePath];
    BOOL shouldUpdate = [s next];
    [s close];

    if (shouldUpdate) {
        [_database executeUpdate:@"UPDATE dropbox_data SET date=?,size=? WHERE filename=?,lowercasepath=?",date,size,filename,lowercasePath];
    } else {
        [_database executeUpdate:@"INSERT INTO dropbox_data (date,size,type,filename,lowercasepath) VALUES (?,?,?,?,?)",date,size,type,filename,lowercasePath];
    }
}

- (void)refreshControlShouldRefresh:(UIRefreshControl *)control {
    [self loadUserID];
}

- (void)loadUserID {
    if (_userID.length == 0) {
        [[NetworkActivityController sharedController]show];
        [DroppinBadassBlocks loadAccountInfoWithCompletionBlock:^(DBAccountInfo *info, NSError *error) {
            [[NetworkActivityController sharedController]hideIfPossible];
            if (error) {
                [UIAlertView showAlertWithTitle:[NSString stringWithFormat:@"Dropbox Error %d",error.code] andMessage:error.localizedDescription];
            } else {
                self.userID = info.userId;
                [self loadUserID];
            }
        }];
    } else {
        NSString *filePath = [kCachesDir stringByAppendingPathComponent:@"cursors.json"];
        NSData *json = [NSData dataWithContentsOfFile:filePath];
        NSMutableDictionary *dict = [[NSFileManager defaultManager]fileExistsAtPath:filePath]?[NSJSONSerialization JSONObjectWithData:json options:NSJSONReadingMutableContainers error:nil]:[NSMutableDictionary dictionary];
        self.cursor = dict[_userID];
        [self updateFileListing];
    }
}

- (void)saveCursor {
    NSString *filePath = [kCachesDir stringByAppendingPathComponent:@"cursors.json"];
    NSData *jsonread = [NSData dataWithContentsOfFile:filePath];
    NSMutableDictionary *dict = [[NSFileManager defaultManager]fileExistsAtPath:filePath]?[NSJSONSerialization JSONObjectWithData:jsonread options:NSJSONReadingMutableContainers error:nil]:[NSMutableDictionary dictionary];
    dict[_userID] = _cursor;
    NSData *json = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONReadingMutableContainers error:nil];
    [json writeToFile:filePath atomically:YES];
}

- (void)updateFileListing {
    [[NetworkActivityController sharedController]show];
    
    [DroppinBadassBlocks loadDelta:_cursor withCompletionHandler:^(NSArray *entries, NSString *cursor, BOOL hasMore, BOOL shouldReset, NSError *error) {
        [[NetworkActivityController sharedController]hideIfPossible];
        if (error) {
            self.shouldMassInsert = NO;
        } else {
            
            if (_shouldStopLoading) {
                return;
            }
            
            if (shouldReset) {
                NSLog(@"Resetting");
                self.cursor = nil;
                [_currentPathItems removeAllObjects];
                self.shouldMassInsert = YES;
                _refreshControl.attributedTitle = [[NSAttributedString alloc]initWithString:@"Initial Load. Be patient..."];
                [self removeAllEntriesForCurrentUser];
            } else {
                _refreshControl.attributedTitle = nil;
            }
            
            self.cursor = cursor;
            
            NSMutableArray *array = [NSMutableArray array];
            
            for (DBDeltaEntry *entry in entries) {
                DBMetadata *item = entry.metadata;
                if (item) {
                    if (item.isDeleted) {
                        [self removeItemWithLowercasePath:entry.lowercasePath];
                    } else {
                        if (_shouldMassInsert) {
                            [array addObject:item];
                        } else {
                            [self addObjectToDatabase:item withLowercasePath:entry.lowercasePath];
                        }
                    }  
                }
            }
            
            if (_shouldMassInsert) {
                [self batchInsert:array];
            }

            if (hasMore) {
                NSLog(@"Continuing");
                [self updateFileListing];
            } else {
                NSLog(@"done");
                [self saveCursor];
                self.shouldMassInsert = NO;
                [self refreshStateWithAnimationStyle:UITableViewRowAnimationFade];
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
        float fileSize = [fileDict[NSFileSize]intValue];
        
        cell.detailTextLabel.text = @"File, ";
        
        if (fileSize < 1024.0) {
            cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingFormat:@"%.0f Byte%@",fileSize,(fileSize > 1)?@"s":@""];
        } else if (fileSize < (1024*1024) && fileSize > 1024.0 ) {
            fileSize = fileSize/1014;
            cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingFormat:@"%.0f KB",fileSize];
        } else if (fileSize < (1024*1024*1024) && fileSize > (1024*1024)) {
            fileSize = fileSize/(1024*1024);
            cell.detailTextLabel.text = [cell.detailTextLabel.text stringByAppendingFormat:@"%.0f MB",fileSize];
        }
    } else {
        cell.detailTextLabel.text = @"Directory";
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    NSDictionary *fileDict = _currentPathItems[indexPath.row];
    NSString *filename = fileDict[NSFileName];
    
    NSString *filetype = (NSString *)fileDict[NSFileType];
    
    if ([filetype isEqualToString:(NSString *)NSFileTypeDirectory]) {
        _navBar.topItem.title = [_navBar.topItem.title stringByAppendingPathComponent:fileDict[NSFileName]];
        [self loadContentsOfDirectory:[_navBar.topItem.title fhs_normalize]];
        [self refreshStateWithAnimationStyle:UITableViewRowAnimationLeft];
    } else {
        NSString *message = [NSString stringWithFormat:@"Do you wish to download \"%@\"?",filename];
        UIActionSheet *actionSheet = [[UIActionSheet alloc]initWithTitle:message completionBlock:^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
            
            NSString *filePath = [_navBar.topItem.title stringByAppendingPathComponent:fileDict[NSFileName]];
            
            if (buttonIndex == 0) {
                DropboxDownload *dl = [DropboxDownload downloadWithPath:filePath];
                [[TaskController sharedController]addTask:dl];
            } else if (buttonIndex == 1) {
                DropboxLinkTask *task = [DropboxLinkTask taskWithFilepath:filePath];
                [[TaskController sharedController]addTask:task];
            }
        } cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Download", @"Get Link", nil];
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
    [[DroppinBadassBlocks sharedInstance]cancelAllMiscRequests];
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
