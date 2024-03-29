//
//  UnzippingTask.m
//  Swift
//
//  Created by Nathaniel Symer on 7/28/13.
//  Copyright (c) 2013 Nathaniel Symer. All rights reserved.
//

#import "UnzippingTask.h"

@interface UnzippingTask ()

@property (nonatomic, strong) NSString *file;

@end

@implementation UnzippingTask

- (id)initWithFile:(NSString *)file {
    self = [super init];
    if (self) {
        self.file = file;
        self.name = file.lastPathComponent;
    }
    return self;
}

+ (UnzippingTask *)taskWithFile:(NSString *)file {
    return [[[self class]alloc]initWithFile:file];
}

- (BOOL)canStop {
    return NO;
}

- (NSString *)verb {
    return @"Decompressing";
}

- (void)stop {
    [super stop];
}

- (void)start {
    [super start];
    [self inflate];
}

- (void)inflate {
    
    if (![[NSFileManager defaultManager]fileExistsAtPath:_file]) {
        [self showFailure];
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            
            @try {
                ZipFile *unzipFile = [[ZipFile alloc]initWithFileName:_file mode:ZipFileModeUnzip];
                NSArray *infos = [unzipFile listFileInZipInfos];
                
                float unachivedBytes = 0;
                float filesize = 0;
                
                for (FileInZipInfo *info in infos) {
                    filesize += info.length;
                }
                
                for (FileInZipInfo *info in infos) {
                    
                    [unzipFile locateFileInZip:info.name];
                    NSString *dirOfZip = [_file stringByDeletingLastPathComponent];
                    NSString *writeLocation = deconflictPath([dirOfZip stringByAppendingPathComponent:info.name]);
                    NSString *slash = [info.name substringFromIndex:[info.name length]-1];
                    
                    if ([slash isEqualToString:@"/"]) {
                        [[NSFileManager defaultManager]createDirectoryAtPath:writeLocation withIntermediateDirectories:NO attributes:nil error:nil];
                    } else {
                        [[NSFileManager defaultManager]createFileAtPath:writeLocation contents:nil attributes:nil];
                        
                        NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:writeLocation];
                        
                        ZipReadStream *read = [unzipFile readCurrentFileInZip];
                        
                        NSMutableData *buffer = [NSMutableData data];
                        do {
                            [buffer setLength:1024*1024];
                            
                            int bytesRead = [read readDataWithBuffer:buffer];
                            if (bytesRead == 0) {
                                break;
                            } else {
                                [buffer setLength:bytesRead];
                                [file writeData:buffer];
                                
                                unachivedBytes = unachivedBytes+bytesRead;
                                
                                dispatch_sync(dispatch_get_main_queue(), ^{
                                    @autoreleasepool {
                                        [self.delegate setProgress:(unachivedBytes/filesize)];
                                    }
                                });
                            }
                        } while (YES);
                        
                        [file closeFile];
                        [read finishedReading];
                    }
                }
                [unzipFile close];
            }
            @catch (NSException *exception) {
                if ([exception.name isEqualToString:kZipExceptionName]) {
                    [UIAlertView showAlertWithTitle:@"Failed to unzip" andMessage:[exception.reason stringByReplacingOccurrencesOfString:kDocsDir withString:@""]];
                } else {
                    @throw exception;
                }
            }
            @finally {
                // statements
            }
        }
        dispatch_sync(dispatch_get_main_queue(), ^{
            @autoreleasepool {
                [self showSuccess];
            }
        });
    });
}

@end
