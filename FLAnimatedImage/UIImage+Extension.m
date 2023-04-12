//
//  UIImage+Extension.m
//  FLAnimatedImage
//
//  Created by Sih Ou-Yang on 2023/4/12.
//  Copyright © 2023 com.flipboard. All rights reserved.
//

#import "UIImage+Extension.h"

#import "WebPImageDecoder.h"

@implementation UIImage (Extension)

+ (UIImage *)animatedImageWithFrames:(NSArray<ImageFrame *> *)imageFrames {
    if (imageFrames.count == 0) {
        return nil;
    }
    NSTimeInterval totalDuration = 0;
    NSMutableArray *images = [[NSMutableArray alloc] init];
    for(int i = 0; i < imageFrames.count; i++) {
        totalDuration += imageFrames[i].duration;
        [images addObject:imageFrames[i].image];
    }
    return [UIImage animatedImageWithImages:[NSArray arrayWithArray:images] duration:totalDuration];
}

@end
