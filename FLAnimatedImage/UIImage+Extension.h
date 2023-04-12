//
//  UIImage+Extension.h
//  FLAnimatedImage
//
//  Created by Sih Ou-Yang on 2023/4/12.
//  Copyright © 2023 com.flipboard. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ImageFrame;

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (Extension)

+ (UIImage * _Nullable)animatedImageWithFrames:(NSArray<ImageFrame *> *)imageFrames;

@end

NS_ASSUME_NONNULL_END
