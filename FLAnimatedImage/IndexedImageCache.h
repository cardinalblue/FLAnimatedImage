//
//  IndexedImageCache.h
//  FLAnimatedImage
//
//  Created by Sih Ou-Yang on 2024/2/23.
//  Copyright © 2024 com.cardinalblue. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface IndexedImageCache : NSObject

- (instancetype _Nonnull)initWithLimit:(NSInteger)limit; // limit represents the size of the cache

- (void)set:(UIImage *_Nullable)image atIndex:(NSInteger)index;

- (nullable UIImage *)imageAtIndex:(NSInteger)index;

- (void)updateTimestampAtIndex:(NSInteger)index;

- (void)removeAll;

@end
