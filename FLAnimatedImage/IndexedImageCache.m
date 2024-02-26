//
//  BlendedImageCache.m
//  FLAnimatedImage
//
//  Created by Sih Ou-Yang on 2024/2/23.
//  Copyright © 2024 com.cardinalblue. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface IndexedImageInfo : NSObject

@property(nonatomic) UIImage *image;
@property(nonatomic) NSTimeInterval timestamp;

@end

@implementation IndexedImageInfo

@end

@interface IndexedImageCache : NSObject

- (instancetype)initWithLimit:(NSInteger)limit;

- (void)add:(UIImage *)image withIndex:(NSInteger)index;
- (nullable UIImage *)imageAtIndex:(NSInteger)index;


@end

@interface IndexedImageCache ()

@property(nonatomic) NSMutableDictionary<NSNumber *, IndexedImageInfo *> *blendedImageDict;

// limit: 0 represents no cache
@property(nonatomic) NSInteger limit;

@end

@implementation IndexedImageCache

-(instancetype)initWithLimit:(NSInteger)limit {
    self = [super init];
    if (self) {
        _blendedImageDict = [[NSMutableDictionary alloc] init];
        _limit = limit;
    }
    return self;
}

- (void)add:(UIImage *)image withIndex:(NSInteger)index {
    if (self.limit == 0) {
        return;
    }
    // if cache reaches limit -> remove the oldest
    if (self.blendedImageDict.count == self.limit) {
        [self removeOldestCache];
    }

    // add to cache
    [self set:image atIndex:index];
}

- (void)set:(UIImage *_Nullable)image atIndex:(NSInteger)index {
    if (image) {
        IndexedImageInfo *info = [[IndexedImageInfo alloc] init];
        info.image = image;
        info.timestamp = [NSDate new].timeIntervalSince1970;
        self.blendedImageDict[@(index)] = info;
    } else {
        self.blendedImageDict[@(index)] = nil;
    }
}

- (UIImage *)imageAtIndex:(NSInteger)index {
    return self.blendedImageDict[@(index)].image;
}

// Update the timestamp for disposing the less used cache
- (void)updateTimestampAtIndex:(NSInteger)index {
    self.blendedImageDict[@(index)].timestamp = [NSDate new].timeIntervalSince1970;
}

- (void)removeOldestCache {
    NSArray *sortedArray = [[self.blendedImageDict allValues] sortedArrayUsingComparator:^NSComparisonResult(IndexedImageInfo * _Nonnull obj1, IndexedImageInfo * _Nonnull obj2) {
        if (obj1.timestamp > obj2.timestamp) {
            return NSOrderedDescending;
        } else if (obj1.timestamp < obj2.timestamp) {
            return NSOrderedAscending;
        } else {
            return NSOrderedSame;
        }
    }];
    IndexedImageInfo *oldest = sortedArray.firstObject;
    NSNumber *key = [self.blendedImageDict allKeysForObject:oldest].firstObject;
    if (key) {
        self.blendedImageDict[key] = nil;
    }
}

- (void)removeAll {
    [self.blendedImageDict removeAllObjects];
}

@end
