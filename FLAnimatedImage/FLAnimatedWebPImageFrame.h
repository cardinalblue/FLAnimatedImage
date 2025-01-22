//
//  FLAnimatedWebPImageFrame.h
//  FLAnimatedImage
//
//  Created by Sih Ou-Yang on 2023/4/20.
//  Copyright © 2023 com.cardinalblue. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLAnimatedWebPImageFrame : NSObject

@property (nonatomic) UIImage *image;
@property (nonatomic) NSTimeInterval duration;

- (instancetype)initWithImage:(UIImage *)image duration:(NSTimeInterval)duration;

@end

NS_ASSUME_NONNULL_END
