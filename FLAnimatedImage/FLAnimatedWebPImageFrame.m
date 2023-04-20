//
//  FLAnimatedWebPImageFrame.m
//  FLAnimatedImage
//
//  Created by Sih Ou-Yang on 2023/4/20.
//  Copyright © 2023 com.cardinalblue. All rights reserved.
//

#import "FLAnimatedWebPImageFrame.h"

@implementation FLAnimatedWebPImageFrame

- (instancetype)initWithImage:(UIImage *)image duration:(NSTimeInterval)duration {
    self = [super init];
    if (self) {
        self.image = image;
        self.duration = duration;
    }
    return self;
}

@end
