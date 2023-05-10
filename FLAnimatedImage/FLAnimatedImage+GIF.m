//
//  FLAnimatedImage+GIF.m
//  
//
//  Created by Sih Ou-Yang on 2023/3/23.
//

#import "FLAnimatedImage+Internal.h"
#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "FLAnimatedGIFDataSource.h"


@implementation FLAnimatedImage(GIF)

+ (FLAnimatedImage *)animatedImageWithGIFData:(NSData *)data {
    // Early return if no data supplied!
    const BOOL hasData = (data.length > 0);
    if (!hasData) {
        FLLog(FLLogLevelError, @"No animated GIF data supplied.");
        return nil;
    }
    //Note: We could leverage `CGImageSourceCreateWithURL` too to add a second initializer `-initWithAnimatedGIFContentsOfURL:`.

    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)data,
                                                               (__bridge CFDictionaryRef)@{(NSString *)kCGImageSourceShouldCache: @NO});
    // Early return on failure!
    if (!imageSource) {
        FLLog(FLLogLevelError, @"Failed to `CGImageSourceCreateWithData` for animated GIF data %@", data);
        return nil;
    }
    // Early return if not GIF!
    CFStringRef imageSourceContainerType = CGImageSourceGetType(imageSource);
    BOOL isGIFData = UTTypeConformsTo(imageSourceContainerType, kUTTypeGIF);

    if (!isGIFData) {
        FLLogError(@"Supplied data is of type %@ and doesn't seem to be GIF data %@", imageSourceContainerType, data);
        return nil;
    }
    // Get `LoopCount`
    // Note: 0 means repeating the animation indefinitely.
    // Image properties example:
    // {
    //     FileSize = 314446;
    //     "{GIF}" = {
    //         HasGlobalColorMap = 1;
    //         LoopCount = 0;
    //     };
    // }
    NSDictionary *imageProperties = (__bridge_transfer NSDictionary *)CGImageSourceCopyProperties(imageSource, NULL);
    NSUInteger loopCount = [[[imageProperties objectForKey:(id)kCGImagePropertyGIFDictionary] objectForKey:(id)kCGImagePropertyGIFLoopCount] unsignedIntegerValue];

    // Iterate through frame images
    size_t imageCount = CGImageSourceGetCount(imageSource);
    CGSize size = CGSizeZero;
    UIImage *posterImage = nil;
    NSUInteger posterImageFrameIndex = 0;
    NSInteger skippedFrameCount = 0;
    NSMutableDictionary *delayTimesForIndexesMutable = [NSMutableDictionary dictionaryWithCapacity:imageCount];
    for (size_t i = 0; i < imageCount; i++) {
        @autoreleasepool {
            const CGImageRef _Nullable frameImageRef = CGImageSourceCreateImageAtIndex(imageSource, i, NULL);
            if (frameImageRef) {
                UIImage *frameImage = [UIImage imageWithCGImage:frameImageRef];
                // Check for valid `frameImage` before parsing its properties as frames can be corrupted (and `frameImage` even `nil` when `frameImageRef` was valid).
                if (frameImage) {
                    // Set poster image
                    if (!posterImage) {
                        posterImage = frameImage;
                        // Set its size to proxy our size.
                        size = posterImage.size;
                        posterImageFrameIndex = i;
                    }
                    // Get `DelayTime`
                    // Note: It's not in (1/100) of a second like still falsely described in the documentation as per iOS 8 (rdar://19507384) but in seconds stored as `kCFNumberFloat32Type`.
                    // Frame properties example:
                    // {
                    //     ColorModel = RGB;
                    //     Depth = 8;
                    //     PixelHeight = 960;
                    //     PixelWidth = 640;
                    //     "{GIF}" = {
                    //         DelayTime = "0.4";
                    //         UnclampedDelayTime = "0.4";
                    //     };
                    // }
                    //
                    NSDictionary *_Nullable const frameProperties = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(imageSource, i, NULL);
                    NSDictionary *_Nullable const framePropertiesGIF = [frameProperties objectForKey:(id)kCGImagePropertyGIFDictionary];

                    // Try to use the unclamped delay time; fall back to the normal delay time.
                    NSNumber *_Nullable delayTime = [framePropertiesGIF objectForKey:(id)kCGImagePropertyGIFUnclampedDelayTime];
                    if (delayTime == nil) {
                        delayTime = [framePropertiesGIF objectForKey:(id)kCGImagePropertyGIFDelayTime];
                    }
                    // If we don't get a delay time from the properties, fall back to `kDelayTimeIntervalDefault` or carry over the preceding frame's value.
                    const NSTimeInterval kDelayTimeIntervalDefault = 0.1;
                    if (delayTime == nil) {
                        if (i == 0) {
                            FLLog(FLLogLevelInfo, @"Falling back to default delay time for first frame %@ because none found in GIF properties %@", frameImage, frameProperties);
                            delayTime = @(kDelayTimeIntervalDefault);
                        } else {
                            FLLog(FLLogLevelInfo, @"Falling back to preceding delay time for frame %zu %@ because none found in GIF properties %@", i, frameImage, frameProperties);
                            delayTime = delayTimesForIndexesMutable[@(i - 1)];
                        }
                    }
                    // Support frame delays as low as `kFLAnimatedImageDelayTimeIntervalMinimum`, with anything below being rounded up to `kDelayTimeIntervalDefault` for legacy compatibility.
                    // To support the minimum even when rounding errors occur, use an epsilon when comparing. We downcast to float because that's what we get for delayTime from ImageIO.
                    if ([delayTime floatValue] < ((float)kFLAnimatedImageDelayTimeIntervalMinimum - FLT_EPSILON)) {
                        FLLog(FLLogLevelInfo, @"Rounding frame %zu's `delayTime` from %f up to default %f (minimum supported: %f).", i, [delayTime floatValue], kDelayTimeIntervalDefault, kFLAnimatedImageDelayTimeIntervalMinimum);
                        delayTime = @(kDelayTimeIntervalDefault);
                    }
                    delayTimesForIndexesMutable[@(i)] = delayTime;
                } else {
                    skippedFrameCount++;
                    FLLog(FLLogLevelInfo, @"Dropping frame %zu because valid `CGImageRef` %@ did result in `nil`-`UIImage`.", i, frameImageRef);
                }
                CFRelease(frameImageRef);
            } else {
                skippedFrameCount++;
                FLLog(FLLogLevelInfo, @"Dropping frame %zu because failed to `CGImageSourceCreateImageAtIndex` with image source %@", i, self->_imageSource);
            }
        }
    }
    NSUInteger frameCount = [delayTimesForIndexesMutable count];
    if (frameCount == 0) {
        FLLogInfo(@"Failed to create any valid frames for GIF with properties %@", imageProperties);
        CFRelease(imageSource);
        return nil;
    } else if (frameCount == 1) {
        // Warn when we only have a single frame but return a valid GIF.
        FLLogInfo(@"Created valid GIF but with only a single frame. Image properties: %@", imageProperties);
    } else {
        // We have multiple frames, rock on!
    }

    FLAnimatedGIFDataSource *dataSource = [[FLAnimatedGIFDataSource alloc] initWithImageSource:imageSource];
    CFRelease(imageSource);
    FLAnimatedImageData *gifData = [[FLAnimatedImageData alloc] initWithData:data type:FLAnimatedImageDataTypeGIF];

    return [[FLAnimatedImage alloc] initWithData:gifData
                                            size:size
                                       loopCount:loopCount
                                      frameCount:frameCount
                               skippedFrameCount:skippedFrameCount
                            delayTimesForIndexes:delayTimesForIndexesMutable
                        preferFrameCacheStrategy:FLAnimatedImagePreferredFrameCacheStrategyOptimizedForTotalFrames
                                     posterImage:posterImage
                                posterImageIndex:posterImageFrameIndex
                                 frameDataSource:dataSource];

}

@end
