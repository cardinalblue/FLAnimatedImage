//
//  FLAnimatedImage+WebP.h
//  Facebook
//
//  Created by Grant Paul.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import <FLAnimatedImage/FLAnimatedImage.h>

typedef NS_ENUM(NSInteger, WebPDecodeType) {
    WebPDecodeBuiltIn,
    WebPDecodeLib
};

@interface FLAnimatedImage (WebP)


+ (FLAnimatedImage *)animatedImageWithWebPData:(NSData *)data decodeType:(WebPDecodeType)type;
//+ (FLAnimatedImage *)builtInAnimatedImageWithWebPData:(NSData *)data;

@end
