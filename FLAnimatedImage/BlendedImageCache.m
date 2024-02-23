//
//  BlendedImageCache.m
//  FLAnimatedImage
//
//  Created by Sih Ou-Yang on 2024/2/23.
//  Copyright © 2024 com.cardinalblue. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface BlendedImageInfo : NSObject

@property(nonatomic) UIImage *image;
@property(nonatomic) NSTimeInterval timestamp;

@end

@implementation BlendedImageInfo

@end

@interface BlendedImageCache : NSObject

- (instancetype)initWithLimit:(NSInteger)limit;

- (void)add:(UIImage *)image withIndex:(NSInteger)index;
- (nullable UIImage *)imageAtIndex:(NSInteger)index;


@end

@interface BlendedImageCache ()

@property(nonatomic) NSMutableDictionary<NSNumber *, BlendedImageInfo *> *blendedImageDict;

// limit: 0 represents no cache
@property(nonatomic) NSInteger limit;

@end

@implementation BlendedImageCache

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
    BlendedImageInfo *info = [[BlendedImageInfo alloc] init];
    info.image = image;
    info.timestamp = [NSDate new].timeIntervalSince1970;
    self.blendedImageDict[@(index)] = info;
}

- (UIImage *)imageAtIndex:(NSInteger)index {
    return self.blendedImageDict[@(index)].image;
}

- (void)removeOldestCache {
    NSArray *sortedArray = [[self.blendedImageDict allValues] sortedArrayUsingComparator:^NSComparisonResult(BlendedImageInfo * _Nonnull obj1, BlendedImageInfo * _Nonnull obj2) {
        if (obj1.timestamp > obj2.timestamp) {
            return NSOrderedDescending;
        } else if (obj1.timestamp < obj2.timestamp) {
            return NSOrderedAscending;
        } else {
            return NSOrderedSame;
        }
    }];
    BlendedImageInfo *oldest = sortedArray.firstObject;
    NSNumber *key = [self.blendedImageDict allKeysForObject:oldest].firstObject;
    if (key) {
        self.blendedImageDict[key] = nil;
    }
}

@end
