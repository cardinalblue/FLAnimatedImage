//
//  WebPImageDecoder.m
//  FLAnimatedImage
//
//  Created by Sih Ou-Yang on 2023/4/10.
//  Copyright © 2023 com.flipboard. All rights reserved.
//

#import "WebPImageDecoder.h"
#import "UIImage+Extension.h"

@implementation ImageFrame

- (instancetype)initWithImage:(UIImage *)image duration:(NSTimeInterval)duration {
    self = [super init];
    if (self) {
        self.image = image;
        self.duration = duration;
    }
    return self;
}

@end

@interface WebPImageDecoder()

@property(nonatomic) CGImageSourceRef source;

@end

@implementation WebPImageDecoder

- (instancetype)initWithData:(NSData *)data {
    self = [super init];
    if (self) {

        CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, (__bridge CFDictionaryRef)@{(id)kCGImageSourceShouldCache: @YES});
        _frameCount = CGImageSourceGetCount(source);
        // Parse the image properties
        NSDictionary *properties = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
        NSDictionary *webPProperties = properties[(__bridge NSString *)kCGImagePropertyWebPDictionary];

        CGFloat pixelWidth = [webPProperties[(__bridge NSString *)kCGImagePropertyWebPCanvasPixelWidth] doubleValue];
        CGFloat pixelHeight = [webPProperties[(__bridge NSString *)kCGImagePropertyWebPCanvasPixelHeight] doubleValue];

        _imageSize = CGSizeMake(pixelWidth, pixelHeight);
    
        _loopCount = [properties[(__bridge NSString *)kCGImagePropertyWebPLoopCount] unsignedIntValue];
        self.source = source;
    }
    [self decodedImageWithData:data];
    return self;
}

- (UIImage * _Nullable)decodedImageWithData:(NSData * _Nullable)data {
    if (!data) {
        return nil;
    }

    if (!self.source) {
        return nil;
    }

    CGFloat scale = 1.0;
    if (self.frameCount == 1) {
        return [self createFrameAtIndex:0 source:self.source scale:scale options:nil];
    } else if (self.frameCount > 1) {
        NSMutableArray<ImageFrame *> *frames = [NSMutableArray arrayWithCapacity:self.frameCount];
        for (size_t i = 0; i < self.frameCount; i++) {
            UIImage *image = [self createFrameAtIndex:i source:self.source scale:scale options:nil];
            if (!image) {
                continue;
            }

            NSTimeInterval duration = [self frameDurationAtIndex:i source:self.source];
            ImageFrame *frame = [[ImageFrame alloc] initWithImage:image duration:duration];
            [frames addObject:frame];
        }

        self.imageFrames = [NSArray arrayWithArray:frames];

        UIImage *animatedImage = [UIImage animatedImageWithFrames:frames];
        return animatedImage;
    } else {
        return nil;
    }
}

- (UIImage * _Nullable)createFrameAtIndex:(NSInteger)index source:(CGImageSourceRef)source scale:(CGFloat)scale options:(NSDictionary<NSString *, id> * _Nullable)options {
    // Some options need to pass to `CGImageSourceCopyPropertiesAtIndex` before `CGImageSourceCreateImageAtIndex`,
    // or ImageIO will ignore them because they parse once :)
    // Parse the image properties
    NSDictionary *properties = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, index, (__bridge CFDictionaryRef)options);
    if (![properties isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, index, (__bridge CFDictionaryRef)options);
    if (!cgImage) {
        return nil;
    }

    UIImageOrientation (^getImageOrientation)(void) = ^{
        NSNumber *orientationValue = properties[(NSString *)kCGImagePropertyOrientation];
        if (![orientationValue isKindOfClass:[NSNumber class]]) {
            return UIImageOrientationUp;
        }
        CGImagePropertyOrientation exifOrientation = (CGImagePropertyOrientation)orientationValue.unsignedIntValue;
        return (UIImageOrientation)exifOrientation;
    };
    UIImageOrientation imageOrientation = getImageOrientation();

    UIImage *image = [[UIImage alloc] initWithCGImage:cgImage scale:scale orientation:imageOrientation];
    CGImageRelease(cgImage);
    return image;
}

- (NSTimeInterval)frameDurationAtIndex:(NSUInteger)index source:(CGImageSourceRef)source
{
    NSDictionary *options = @{
        (NSString *)kCGImageSourceShouldCacheImmediately: @YES,
        (NSString *)kCGImageSourceShouldCache: @YES // Always cache to reduce CPU usage
    };
    NSTimeInterval frameDuration = 0.1;
    CFDictionaryRef cfFrameProperties = CGImageSourceCopyPropertiesAtIndex(source, index, (__bridge CFDictionaryRef)options);
    NSDictionary *frameProperties = (__bridge_transfer NSDictionary *)cfFrameProperties;
    if (frameProperties) {
        NSDictionary *containerProperties = frameProperties[(NSString *)kCGImagePropertyWebPDictionary];
        if (containerProperties) {
            NSNumber *unclampedDelayTime = containerProperties[(NSString *)kCGImagePropertyWebPUnclampedDelayTime];
            if (unclampedDelayTime.floatValue > 0.011) {
                frameDuration = unclampedDelayTime.floatValue;
            } else {
                NSNumber *delayTime = containerProperties[(NSString *)kCGImagePropertyWebPDelayTime];
                if (delayTime.floatValue > 0.011) {
                    frameDuration = delayTime.floatValue;
                }
            }
        }
    }
    // Many annoying ads specify a 0 duration to make an image flash as quickly as possible.
    // We follow Firefox's behavior and use a duration of 100 ms for any frames that specify
    // a duration of <= 10 ms. See <rdar://problem/7689300> and <http://webkit.org/b/36082>
    // for more information.
    //
    if (frameDuration < 0.011) {
        frameDuration = 0.1;
    }
    return frameDuration;
}

@end
