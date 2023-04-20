//
//  FLAnimatedGIFDataSource.m
//  Facebook
//
//  Created by Ben Hiller.
//  Copyright (c) 2014-2015 Facebook. All rights reserved.
//

#import "FLAnimatedGIFDataSource.h"
#import "FLAnimatedImage.h"
#import "FLAnimatedImage+Internal.h"
#import "UIImage+Extension.h"

#import <CoreGraphics/CoreGraphics.h>

// From vm_param.h, define for iOS 8.0 or higher to build on device.
#ifndef BYTE_SIZE
#define BYTE_SIZE 8 // byte size in bits
#endif

@implementation FLAnimatedGIFDataSource
{
    // Use old school ivar instead of property for retained non-object types (CF type, dispatch "object") to avoid ARC confusion: http://stackoverflow.com/questions/9684972/strong-property-with-attribute-nsobject-for-a-cf-type-doesnt-retain/9690656#9690656
    CGImageSourceRef _imageSource;
}

- (instancetype)initWithImageSource:(CGImageSourceRef)imageSource
{
    if (self = [super init]) {
        NSAssert(imageSource != NULL, @"imageSource must not be NULL");
        CFRetain(imageSource);
        _imageSource = imageSource;
    }

    return self;
}

- (void)dealloc
{
    if (_imageSource) {
        CFRelease(_imageSource);
    }
}

#pragma mark - Frame Loading

- (UIImage *)imageAtIndex:(NSUInteger)index
{
    // It's very important to use the cached `_imageSource` since the random access to a frame with `CGImageSourceCreateImageAtIndex` turns from an O(1) into an O(n) operation when re-initializing the image source every time.
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(_imageSource, index, NULL);
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    CFRelease(imageRef);

    // Loading in the image object is only half the work, the displaying image view would still have to synchronously wait and decode the image, so we go ahead and do that here on the background thread.
    image = [UIImage predrawnImageFromImage:image];

    return image;
}

- (BOOL)frameRequiresBlendingWithPreviousFrame:(NSUInteger)index
{
    // CGImageSource thankfully handles all required blending for us.
    return NO;
}

- (UIImage *)blendImage:(UIImage *)image atIndex:(NSUInteger)index withPreviousImage:(UIImage *)previousImage
{
    // This should never be called, as `frameRequiresBlendingWithPreviousFrame` always returns NO.
    NSAssert(NO, @"-[FLAnimatedGIFDataSource blendImage:atIndex:withPreviousImage: should never be called");
    return nil;
}

@end

