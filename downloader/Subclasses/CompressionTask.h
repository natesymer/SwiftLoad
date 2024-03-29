//
//  CompressionTask.h
//  Swift
//
//  Created by Nathaniel Symer on 7/28/13.
//  Copyright (c) 2013 Nathaniel Symer. All rights reserved.
//

#import "Task.h"

@interface CompressionTask : Task

+ (CompressionTask *)taskWithItems:(NSArray *)items rootDirectory:(NSString *)rootDir andZipFile:(NSString *)zipFile;

@end
