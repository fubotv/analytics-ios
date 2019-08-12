//
//  SEGUserDefaultsStorage.h
//  Analytics
//
//  Created by Sergei Shatunov
//  Copyright © 2019 Segment. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SEGFuboUserDefaults : NSObject {
    NSUInteger currentSize;
    NSUserDefaults *defaults;
    NSMutableDictionary *currentSizes;
    Boolean isInError;
}

- (void)removeObjectForKey:(NSString *)key;
- (void)removeAll;

- (BOOL) setObject:(NSObject *)data forKey:(NSString *)key;
- (id) objectForKey:(NSString *)key;
- (void) synchronize;

@end
