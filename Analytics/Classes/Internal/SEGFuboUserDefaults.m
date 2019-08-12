//
//  SEGUserDefaultsStorage.m
//  Analytics
//
//  Created by Sergei Shatunov
//  Copyright © 2019 Segment. All rights reserved.
//

#import "SEGFuboUserDefaults.h"
#import <malloc/malloc.h>
#include <objc/runtime.h>

#define SIZE_STORAGE_LIMIT 850100 //900kb - in fact just 450 with key dublication
#define SIZE_CLEAR_THRESHHOLD 470100 //500

#define CUSTOM_STORAGE_NAME @"FUBO_SEG_CST_STORAGE_XL"

@implementation SEGFuboUserDefaults

- (instancetype)init
{
    if (self = [super init]) {
        defaults = [[NSUserDefaults alloc] initWithSuiteName:CUSTOM_STORAGE_NAME];
        currentSize = [self getSizeOfUserDefaults:CUSTOM_STORAGE_NAME];
        currentSizes = [[NSMutableDictionary alloc] init];
        isInError = NO;
        
        if (currentSize > SIZE_CLEAR_THRESHHOLD) {
            [self removeAll];
            NSLog(@"SFS Queue cleared", currentSize);
        }
        
        NSObject *currentQueue = [defaults objectForKey:@"SEGQueue"];
        if (currentQueue) {
            NSUInteger qSize = [self getSize:currentQueue];
            currentSizes[@"SEGQueue"] = @(qSize > currentSize ? currentSize : qSize);
        }
        
         NSLog(@"SFS Start. current size: %zd", currentSize);
        
//        [[NSNotificationCenter defaultCenter] addObserverForName:NSUserDefaultsSizeLimitExceededNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification * _Nonnull note) {
//            NSLog(@"SFS  ---- Limit reached NSUserDefaultsSizeLimitExceededNotification");
//        }];
    }
    return self;
}

#pragma mark sizes of file

-(NSURL*) getUDFilePath:(NSString *)path {
    NSString *route = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    if (!path) {
        return nil;
    }
    NSString *filepath = [NSString stringWithFormat:@"%@/Preferences/%@.plist", route, path];
    return [NSURL URLWithString:filepath];
}

-(NSUInteger) getSizeOfUserDefaults:(NSString *)path {
    NSURL *route = [self getUDFilePath:path];
    if (!route) {
        return 0;
    }
    
    NSString *routeString = [route path];
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:routeString];

    if (data) {
        return data.length;
    } else {
        return 0;
    }
}

#pragma mark interface

- (void)removeObjectForKey:(NSString *)key
{
    NSUInteger currentPayloadSize = currentSizes[key] ? ((NSNumber *)currentSizes[key]).integerValue : 0;
    if (currentPayloadSize > 0) {
        currentSize -= currentPayloadSize;
    }
    
    [defaults removeObjectForKey:key];
}

- (void)removeAll
{
    for (NSString *key in defaults.dictionaryRepresentation.allKeys) {
        [defaults removeObjectForKey:key];
    }
    [defaults synchronize];
    currentSize = 0;
}

-(id) objectForKey:(NSString *)key {
    return [defaults objectForKey:key];
}


-(BOOL) setObject:(NSObject *)data forKey:(NSString *)key {
    NSUInteger newPayloadSize = [self getSize: data];
    NSUInteger currentPayloadSize = currentSizes[key] ? ((NSNumber *)currentSizes[key]).integerValue : 0;
//    NSLog(@"SFS  ----");
//    NSLog(@"SFS current size: %zd, new data: %zd, same key data %zd, %@", currentSize, newPayloadSize, currentPayloadSize, key);
    if (newPayloadSize + currentSize > SIZE_STORAGE_LIMIT) {
        NSLog(@"SFS - OUT OF QUOTA BY SIZE OF STORAGE");
        if (isInError == NO) {
            NSDictionary *error = [self errorPayload:@"STORAGE_OUT_OF_QUOTA_BY_SIZE" payloadSize: newPayloadSize storageSize:currentSize];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"STORAGE_OUT_OF_QUOTA_BY_SIZE" object: error];
        }
        
        isInError = YES;
        return NO;
    }
    
    if (isInError == YES) {
        NSLog(@"SFS - RESTORED FROM OUT OF QUOTA");
        NSDictionary *error = [self errorPayload:@"STORAGE_ESCAPED_OUT_OF_QUOTA_BY_SIZE" payloadSize:newPayloadSize storageSize:currentSize];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"STORAGE_ESCAPED_OUT_OF_QUOTA_BY_SIZE" object: error];
        isInError = NO;
    }
    currentSizes[key] = @(newPayloadSize);
//    NSLog(@"SFS Total size. current size - %d, plusDiff - %d, minusDiff - %d, after update - %d", currentSize, newPayloadSize, currentPayloadSize, (currentSize + newPayloadSize - currentPayloadSize));
    currentSize += (newPayloadSize - currentPayloadSize);
    [defaults setObject:data forKey:key];
    return YES;
}

-(void) synchronize {
    [defaults synchronize];
}

#pragma mark support

-(NSUInteger) getSize:(NSObject *) data {
    if (!data) {
        return 0;
    }
    
    NSData *dataArchive = [NSKeyedArchiver archivedDataWithRootObject:data];
    NSInteger objsize = dataArchive.length;
    
    if (objsize > 0) {
        return objsize;
    } else {
        return 0;
    }
}

-(NSDictionary *) errorPayload:(NSString *)reason payloadSize:(NSUInteger )payloadSize storageSize:(NSUInteger)storageSize {
    return @{@"reason": reason, @"payloadSize": @(payloadSize), @"storageSize": @(storageSize)};
}

@end
