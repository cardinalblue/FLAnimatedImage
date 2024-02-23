//
//  BlendedImageCache.h
//  FLAnimatedImage
//
//  Created by Sih Ou-Yang on 2024/2/23.
//  Copyright © 2024 com.cardinalblue. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface BlendedImageCache : NSObject

- (instancetype _Nonnull)initWithLimit:(NSInteger)limit; // limit represents the size of the cache

- (void)add:(UIImage *_Nonnull)image withIndex:(NSInteger)index;

- (nullable UIImage *)imageAtIndex:(NSInteger)index;

@end
