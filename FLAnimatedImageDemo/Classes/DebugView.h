//
//  DebugView.h
//  FLAnimatedImageDemo
//
//  Created by Raphael Schaad on 4/1/14.
//  Copyright (c) Flipboard. All rights reserved.
//


@import FLAnimatedImage;
@import UIKit;

typedef NS_ENUM(NSUInteger, DebugViewStyle) {
    DebugViewStyleDefault,
    DebugViewStyleCondensed
};


// Conforms to private FLAnimatedImageDebugDelegate and FLAnimatedImageViewDebugDelegate protocols, used in sample project.
@interface DebugView : UIView <FLAnimatedImageDebugDelegate>

@property (nonatomic, weak) FLAnimatedImage *image;
@property (nonatomic, weak) FLAnimatedImageView *imageView;
@property (nonatomic, assign) DebugViewStyle style;

@end
