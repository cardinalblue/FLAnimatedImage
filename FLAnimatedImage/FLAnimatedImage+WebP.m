//  FLAnimatedImage+WebP.m
//  Facebook
//
//  Created by Grant Paul.
//  Copyright (c) 2015 Facebook. All rights reserved.

#import "FLAnimatedImage+WebP.h"
#import "FLAnimatedImage+Internal.h"
#import "FLAnimatedWebPDataSource.h"
#import "WebPImageDecoder.h"

@implementation FLAnimatedImage (WebP)

+ (FLAnimatedImage *)animatedImageWithWebPData:(NSData *)data
{
    UIImage *posterImage = nil;
    NSUInteger posterImageFrameIndex = 0;
    NSUInteger skippedFrameCount = 0;

    WebPImageDecoder *decoder = [[WebPImageDecoder alloc] initWithData:data];
    NSMutableDictionary *delayTimesForIndexesMutable = [NSMutableDictionary dictionaryWithCapacity:decoder.frameCount];

    NSArray<ImageFrame *> *imageFrames = decoder.imageFrames;
    for(int i = 0; i < decoder.frameCount; i++) {
        NSTimeInterval delayTime = imageFrames[i].duration;
        delayTimesForIndexesMutable[@(i)] = FLDelayTimeFloor(@((double)delayTime / 1000));
        if(posterImage == nil) {
            posterImage = imageFrames[i].image;
            posterImageFrameIndex = i;
            if (!posterImage) {
                skippedFrameCount++;
            }
        }
    }

    FLAnimatedWebPDataSource *dataSource = [[FLAnimatedWebPDataSource alloc] initWithDecoder:decoder];
    FLAnimatedImageData *webPData = [[FLAnimatedImageData alloc] initWithData:data type:FLAnimatedImageDataTypeWebP];

    FLAnimatedImage * image = [[FLAnimatedImage alloc] initWithData:webPData
                                                               size:decoder.imageSize
                                                          loopCount:decoder.loopCount
                                                         frameCount:decoder.frameCount
                                                  skippedFrameCount:skippedFrameCount
                                               delayTimesForIndexes:delayTimesForIndexesMutable
                                                        posterImage:posterImage
                                                   posterImageIndex:posterImageFrameIndex
                                                    frameDataSource:dataSource];
    return image;
}

@end
