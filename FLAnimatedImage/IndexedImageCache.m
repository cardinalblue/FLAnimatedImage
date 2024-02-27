//
//  BlendedImageCache.m
//  FLAnimatedImage
//
//  Created by Sih Ou-Yang on 2024/2/23.
//  Copyright © 2024 com.cardinalblue. All rights reserved.
//

#import "IndexedImageCache.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface IndexedImageInfo : NSObject

@property(nonatomic) UIImage *image;
@property(nonatomic) NSTimeInterval timestamp;

@end

@implementation IndexedImageInfo

@end


@interface IndexedImageCache ()

@property(nonatomic) NSMutableDictionary<NSNumber *, IndexedImageInfo *> *imageInfoDict;

// limit: 0 represents no cache
@property(nonatomic) NSInteger limit;

@end

@implementation IndexedImageCache

-(instancetype)initWithLimit:(NSInteger)limit {
    self = [super init];
    if (self) {
        _imageInfoDict = [[NSMutableDictionary alloc] init];
        _limit = limit;
    }
    return self;
}

- (void)set:(UIImage *)image atIndex:(NSInteger)index {
    if (self.limit == 0) {
        return;
    }
    // if cache reaches limit -> remove the oldest
    if (self.imageInfoDict.count == self.limit) {
        [self removeOldestCache];
    }

    // add to cache
    if (image) {
        IndexedImageInfo *info = [[IndexedImageInfo alloc] init];
        info.image = image;
        info.timestamp = [NSDate new].timeIntervalSince1970;
        self.imageInfoDict[@(index)] = info;
    } else {
        self.imageInfoDict[@(index)] = nil;
    }
}

- (UIImage *)imageAtIndex:(NSInteger)index {
    return self.imageInfoDict[@(index)].image;
}

// Update the timestamp for disposing the less used cache
- (void)updateTimestampAtIndex:(NSInteger)index {
    self.imageInfoDict[@(index)].timestamp = [NSDate new].timeIntervalSince1970;
}

- (void)removeOldestCache {
    NSNumber *minKey = nil;
    NSInteger oldestTimestamp = NSIntegerMax;
    for (NSNumber *key in self.imageInfoDict.allKeys) {
        IndexedImageInfo *info = self.imageInfoDict[key];
        if (info.timestamp < oldestTimestamp) {
            oldestTimestamp = info.timestamp;
            minKey = key;
        }
    }
    self.imageInfoDict[minKey] = nil;
}

- (void)removeAll {
    [self.imageInfoDict removeAllObjects];
}

@end
