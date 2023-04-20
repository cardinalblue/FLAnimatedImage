//
//  FLAnimatedImage+WebP.h
//  Facebook
//
//  Created by Grant Paul.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import <FLAnimatedImage/FLAnimatedImage.h>

typedef NS_ENUM(NSInteger, WebPDecodeType) {
    WebPDecodeSystem, // use the iOS 14 built-in feature to decode webp
    WebPDecodeLibWebP
};

@interface FLAnimatedImage (WebP)

+ (FLAnimatedImage *)animatedImageWithWebPData:(NSData *)data decodeType:(WebPDecodeType)type;

@end
