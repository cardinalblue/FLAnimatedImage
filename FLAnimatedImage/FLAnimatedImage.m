//
//  FLAnimatedImage.m
//  Flipboard
//
//  Created by Raphael Schaad on 7/8/13.
//  Copyright (c) Flipboard. All rights reserved.
//


#import "FLAnimatedImage.h"
#import <ImageIO/ImageIO.h>
#if __has_include(<MobileCoreServices/MobileCoreServices.h>)
#import <MobileCoreServices/MobileCoreServices.h>
#else
#import <CoreServices/CoreServices.h>
#endif

#import "FLAnimatedImageData.h"
#import "FLAnimatedImage+Internal.h"
#import "FLAnimatedImageFrameCache.h"



// From vm_param.h, define for iOS 8.0 or higher to build on device.
#ifndef BYTE_SIZE
    #define BYTE_SIZE 8 // byte size in bits
#endif

#define MEGABYTE (1024 * 1024)

// This is how the fastest browsers do it as per 2012: http://nullsleep.tumblr.com/post/16524517190/animated-gif-minimum-frame-delay-browser-compatibility
const NSTimeInterval kFLAnimatedImageDelayTimeIntervalMinimum = 0.02;

// An animated image's data size (dimensions * frameCount) category; its value is the max allowed memory (in MB).
// E.g.: A 100x200px GIF with 30 frames is ~2.3MB in our pixel format and would fall into the `FLAnimatedImageDataSizeCategoryAll` category.
typedef NS_ENUM(NSUInteger, FLAnimatedImageDataSizeCategory) {
    FLAnimatedImageDataSizeCategoryAll = 10,       // All frames permanently in memory (be nice to the CPU)
    FLAnimatedImageDataSizeCategoryDefault = 75,   // A frame cache of default size in memory (usually real-time performance and keeping low memory profile)
    FLAnimatedImageDataSizeCategoryOnDemand = 250, // Only keep one frame at the time in memory (easier on memory, slowest performance)
    FLAnimatedImageDataSizeCategoryUnsupported     // Even for one frame too large, computer says no.
};

typedef NS_ENUM(NSUInteger, FLAnimatedImageFrameCacheSize) {
    FLAnimatedImageFrameCacheSizeNoLimit = 0,                // 0 means no specific limit
    FLAnimatedImageFrameCacheSizeLowMemory = 1,              // The minimum frame cache size; this will produce frames on-demand.
    FLAnimatedImageFrameCacheSizeGrowAfterMemoryWarning = 2, // If we can produce the frames faster than we consume, one frame ahead will already result in a stutter-free playback.
    FLAnimatedImageFrameCacheSizeBest = 5                 // Build up a comfy buffer window to cope with CPU hiccups etc.
};

@protocol FLAnimatedImageViewDebugDelegate;

#if defined(DEBUG) && DEBUG
@interface FLAnimatedImage () <FLAnimatedImageDebugDelegate>
#else
@interface FLAnimatedImage ()
#endif

@property (nonatomic, assign, readonly) NSUInteger frameCacheSizeOptimal; // The optimal number of frames to cache based on image size & number of frames; never changes
@property (nonatomic, assign, readonly, getter=isPredrawingEnabled) BOOL predrawingEnabled; // Enables predrawing of images to improve performance.
@property (nonatomic, assign) NSUInteger frameCacheSizeMaxInternal; // Allow to cap the cache size e.g. when memory warnings occur; 0 means no specific limit (default)
@property (nonatomic, assign) NSUInteger requestedFrameIndex; // Most recently requested frame index
@property (nonatomic, assign, readonly) NSUInteger posterImageFrameIndex; // Index of non-purgable poster image; never changes
@property (nonatomic, strong, readonly) NSMutableDictionary *cachedFramesForIndexes;
@property (nonatomic, strong, readonly) NSMutableIndexSet *cachedFrameIndexes; // Indexes of cached frames
@property (nonatomic, strong, readonly) NSMutableIndexSet *requestedFrameIndexes; // Indexes of frames that are currently produced in the background
@property (nonatomic, strong, readonly) NSIndexSet *allFramesIndexSet; // Default index set with the full range of indexes; never changes
@property (nonatomic, assign) NSUInteger memoryWarningCount;
@property (nonatomic, strong, readonly) dispatch_queue_t serialQueue;
@property (nonatomic, strong, readonly) __attribute__((NSObject)) CGImageSourceRef imageSource;

@property (nonatomic, strong) FLAnimatedImageFrameCache *frameCache;

// The weak proxy is used to break retain cycles with delayed actions from memory warnings.
// We are lying about the actual type here to gain static type checking and eliminate casts.
// The actual type of the object is `FLWeakProxy`.
@property (nonatomic, strong, readonly) FLAnimatedImage *weakProxy;

@end

static NSHashTable *allAnimatedImagesWeak;

@implementation FLAnimatedImage

#pragma mark - Accessors
#pragma mark Public

// This is the definite value the frame cache needs to size itself to.
- (NSUInteger)frameCacheSizeCurrent
{
    NSUInteger frameCacheSizeCurrent = self.frameCacheSizeOptimal;
    
    // If set, respect the caps.
    if (self.frameCacheSizeMax > FLAnimatedImageFrameCacheSizeNoLimit) {
        frameCacheSizeCurrent = MIN(frameCacheSizeCurrent, self.frameCacheSizeMax);
    }
    
    if (self.frameCacheSizeMaxInternal > FLAnimatedImageFrameCacheSizeNoLimit) {
        frameCacheSizeCurrent = MIN(frameCacheSizeCurrent, self.frameCacheSizeMaxInternal);
    }
    
    return frameCacheSizeCurrent;
}


- (void)setFrameCacheSizeMax:(NSUInteger)frameCacheSizeMax
{
    if (_frameCacheSizeMax != frameCacheSizeMax) {
        
        // Remember whether the new cap will cause the current cache size to shrink; then we'll make sure to purge from the cache if needed.
        const BOOL willFrameCacheSizeShrink = (frameCacheSizeMax < self.frameCacheSizeCurrent);
        
        // Update the value
        _frameCacheSizeMax = frameCacheSizeMax;
        
        if (willFrameCacheSizeShrink) {
            [self purgeFrameCacheIfNeeded];
        }
    }
}


#pragma mark Private

- (void)setFrameCacheSizeMaxInternal:(NSUInteger)frameCacheSizeMaxInternal
{
    if (_frameCacheSizeMaxInternal != frameCacheSizeMaxInternal) {
        
        // Remember whether the new cap will cause the current cache size to shrink; then we'll make sure to purge from the cache if needed.
        BOOL willFrameCacheSizeShrink = (frameCacheSizeMaxInternal < self.frameCacheSizeCurrent);
        
        // Update the value
        _frameCacheSizeMaxInternal = frameCacheSizeMaxInternal;
        
        if (willFrameCacheSizeShrink) {
            [self purgeFrameCacheIfNeeded];
        }
    }
}


#pragma mark - Life Cycle

+ (void)initialize
{
    if (self == [FLAnimatedImage class]) {
        // UIKit memory warning notification handler shared by all of the instances
        allAnimatedImagesWeak = [NSHashTable weakObjectsHashTable];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            // UIKit notifications are posted on the main thread. didReceiveMemoryWarning: is expecting the main run loop, and we don't lock on allAnimatedImagesWeak
            NSAssert([NSThread isMainThread], @"Received memory warning on non-main thread");
            // Get a strong reference to all of the images. If an instance is returned in this array, it is still live and has not entered dealloc.
            // Note that FLAnimatedImages can be created on any thread, so the hash table must be locked.
            NSArray *images = nil;
            @synchronized(allAnimatedImagesWeak) {
                images = [[allAnimatedImagesWeak allObjects] copy];
            }
            // Now issue notifications to all of the images while holding a strong reference to them
            [images makeObjectsPerformSelector:@selector(didReceiveMemoryWarning:) withObject:note];
        }];
    }
}

- (instancetype)initWithData:(FLAnimatedImageData *)data
                        size:(CGSize)size
                   loopCount:(NSUInteger)loopCount
                  frameCount:(NSUInteger)frameCount
           skippedFrameCount:(NSUInteger)skippedFrameCount
        delayTimesForIndexes:(NSDictionary *)delayTimesForIndexes
    preferFrameCacheStrategy:(FLAnimatedImagePreferredFrameCacheStrategy)strategy
                 posterImage:(UIImage *)posterImage
            posterImageIndex:(NSUInteger)posterImageIndex
             frameDataSource:(id<FLAnimatedImageFrameDataSource>)frameDataSource;
{
    if (self = [super init]) {
        _frameDataSource = frameDataSource;
        _frameCache = [[FLAnimatedImageFrameCache alloc] initWithFrameCount:frameCount
                                                          skippedFrameCount:skippedFrameCount
                                                                  frameSize:CGImageGetBytesPerRow(posterImage.CGImage) * size.height
                                                   preferFrameCacheStrategy:strategy
                                                                posterImage:posterImage
                                                           posterImageIndex:posterImageIndex
                                                                 dataSource:frameDataSource];
#if defined(DEBUG) && DEBUG
        _frameCache.debug_delegate = self;
#endif
        _posterImage = posterImage;
        _frameCount = frameCount;
        _size = size;
        _loopCount = loopCount;
        _delayTimesForIndexes = [delayTimesForIndexes copy];
        _animatedImageData = data;
        _imageSource = CGImageSourceCreateWithData(
                                                   (__bridge CFDataRef)_animatedImageData.data
                                                   ,(__bridge CFDictionaryRef)@{(NSString *)kCGImageSourceShouldCache: @NO}
                                                   );
    }
    return self;
}


- (void)dealloc
{
    if (_weakProxy) {
        [NSObject cancelPreviousPerformRequestsWithTarget:_weakProxy];
    }
    
    if (_imageSource) {
        CFRelease(_imageSource);
    }
}


#pragma mark - Public Methods

// See header for more details.
// Note: both consumer and producer are throttled: consumer by frame timings and producer by the available memory (max buffer window size).
- (UIImage *)imageLazilyCachedAtIndex:(NSUInteger)index
{
    return [self.frameCache cachedImageAtIndex:index];
}


// Only called once from `-imageLazilyCachedAtIndex` but factored into its own method for logical grouping.
- (void)addFrameIndexesToCache:(NSIndexSet *)frameIndexesToAddToCache
{
    // Order matters. First, iterate over the indexes starting from the requested frame index.
    // Then, if there are any indexes before the requested frame index, do those.
    const NSRange firstRange = NSMakeRange(self.requestedFrameIndex, self.frameCount - self.requestedFrameIndex);
    const NSRange secondRange = NSMakeRange(0, self.requestedFrameIndex);
    if (firstRange.length + secondRange.length != self.frameCount) {
        FLLog(FLLogLevelWarn, @"Two-part frame cache range doesn't equal full range.");
    }
    
    // Add to the requested list before we actually kick them off, so they don't get into the queue twice.
    [self.requestedFrameIndexes addIndexes:frameIndexesToAddToCache];
    
    // Lazily create dedicated isolation queue.
    if (!self.serialQueue) {
        _serialQueue = dispatch_queue_create("com.flipboard.framecachingqueue", DISPATCH_QUEUE_SERIAL);
    }
    
    // Start streaming requested frames in the background into the cache.
    // Avoid capturing self in the block as there's no reason to keep doing work if the animated image went away.
    __weak __typeof(self) weakSelf = self;
    dispatch_async(self.serialQueue, ^{
        // Produce and cache next needed frame.
        void (^frameRangeBlock)(NSRange, BOOL *) = ^(NSRange range, BOOL *stop) {
            // Iterate through contiguous indexes; can be faster than `enumerateIndexesInRange:options:usingBlock:`.
            for (NSUInteger i = range.location; i < NSMaxRange(range); i++) {
#if defined(DEBUG) && DEBUG
                const CFTimeInterval predrawBeginTime = CACurrentMediaTime();
#endif
                UIImage *const image = [weakSelf imageAtIndex:i];
#if defined(DEBUG) && DEBUG
                const CFTimeInterval predrawDuration = CACurrentMediaTime() - predrawBeginTime;
                CFTimeInterval slowdownDuration = 0.0;
                if ([self.debug_delegate respondsToSelector:@selector(debug_animatedImagePredrawingSlowdownFactor:)]) {
                    CGFloat predrawingSlowdownFactor = [self.debug_delegate debug_animatedImagePredrawingSlowdownFactor:self];
                    slowdownDuration = predrawDuration * predrawingSlowdownFactor - predrawDuration;
                    [NSThread sleepForTimeInterval:slowdownDuration];
                }
                FLLog(FLLogLevelVerbose, @"Predrew frame %lu in %f ms for animated image: %@", (unsigned long)i, (predrawDuration + slowdownDuration) * 1000, self);
#endif
                // The results get returned one by one as soon as they're ready (and not in batch).
                // The benefits of having the first frames as quick as possible outweigh building up a buffer to cope with potential hiccups when the CPU suddenly gets busy.
                if (image && weakSelf) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        weakSelf.cachedFramesForIndexes[@(i)] = image;
                        [weakSelf.cachedFrameIndexes addIndex:i];
                        [weakSelf.requestedFrameIndexes removeIndex:i];
#if defined(DEBUG) && DEBUG
                        if ([weakSelf.debug_delegate respondsToSelector:@selector(debug_animatedImage:didUpdateCachedFrames:)]) {
                            [weakSelf.debug_delegate debug_animatedImage:weakSelf didUpdateCachedFrames:weakSelf.cachedFrameIndexes];
                        }
#endif
                    });
                }
            }
        };
        
        [frameIndexesToAddToCache enumerateRangesInRange:firstRange options:0 usingBlock:frameRangeBlock];
        [frameIndexesToAddToCache enumerateRangesInRange:secondRange options:0 usingBlock:frameRangeBlock];
    });
}

#pragma mark - Private Methods
#pragma mark Frame Loading

- (UIImage *)imageAtIndex:(NSUInteger)index
{
    // It's very important to use the cached `_imageSource` since the random access to a frame with `CGImageSourceCreateImageAtIndex` turns from an O(1) into an O(n) operation when re-initializing the image source every time.
    const CGImageRef _Nullable imageRef = CGImageSourceCreateImageAtIndex(_imageSource, index, NULL);

    // Early return for nil
    if (!imageRef) {
        return nil;
    }

    UIImage *image = [UIImage imageWithCGImage:imageRef];
    CFRelease(imageRef);
    
    // Loading in the image object is only half the work, the displaying image view would still have to synchronosly wait and decode the image, so we go ahead and do that here on the background thread.
    if (self.isPredrawingEnabled) {
        image = [[self class] predrawnImageFromImage:image];
    }
    
    return image;
}


#pragma mark Frame Caching

- (NSMutableIndexSet *)frameIndexesToCache
{
    NSMutableIndexSet *indexesToCache = nil;
    // Quick check to avoid building the index set if the number of frames to cache equals the total frame count.
    if (self.frameCacheSizeCurrent == self.frameCount) {
        indexesToCache = [self.allFramesIndexSet mutableCopy];
    } else {
        indexesToCache = [[NSMutableIndexSet alloc] init];
        
        // Add indexes to the set in two separate blocks- the first starting from the requested frame index, up to the limit or the end.
        // The second, if needed, the remaining number of frames beginning at index zero.
        const NSUInteger firstLength = MIN(self.frameCacheSizeCurrent, self.frameCount - self.requestedFrameIndex);
        const NSRange firstRange = NSMakeRange(self.requestedFrameIndex, firstLength);
        [indexesToCache addIndexesInRange:firstRange];
        const NSUInteger secondLength = self.frameCacheSizeCurrent - firstLength;
        if (secondLength > 0) {
            NSRange secondRange = NSMakeRange(0, secondLength);
            [indexesToCache addIndexesInRange:secondRange];
        }
        // Double check our math, before we add the poster image index which may increase it by one.
        if ([indexesToCache count] != self.frameCacheSizeCurrent) {
            FLLog(FLLogLevelWarn, @"Number of frames to cache doesn't equal expected cache size.");
        }
        
        [indexesToCache addIndex:self.posterImageFrameIndex];
    }
    
    return indexesToCache;
}


- (void)purgeFrameCacheIfNeeded
{
    // Purge frames that are currently cached but don't need to be.
    // But not if we're still under the number of frames to cache.
    // This way, if all frames are allowed to be cached (the common case), we can skip all the `NSIndexSet` math below.
    if ([self.cachedFrameIndexes count] > self.frameCacheSizeCurrent) {
        NSMutableIndexSet *indexesToPurge = [self.cachedFrameIndexes mutableCopy];
        [indexesToPurge removeIndexes:[self frameIndexesToCache]];
        [indexesToPurge enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
            // Iterate through contiguous indexes; can be faster than `enumerateIndexesInRange:options:usingBlock:`.
            for (NSUInteger i = range.location; i < NSMaxRange(range); i++) {
                [self.cachedFrameIndexes removeIndex:i];
                [self.cachedFramesForIndexes removeObjectForKey:@(i)];
                // Note: Don't `CGImageSourceRemoveCacheAtIndex` on the image source for frames that we don't want cached any longer to maintain O(1) time access.
#if defined(DEBUG) && DEBUG
                if ([self.debug_delegate respondsToSelector:@selector(debug_animatedImage:didUpdateCachedFrames:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.debug_delegate debug_animatedImage:self didUpdateCachedFrames:self.cachedFrameIndexes];
                    });
                }
#endif
            }
        }];
    }
}


- (void)growFrameCacheSizeAfterMemoryWarning:(NSNumber *)frameCacheSize
{
    self.frameCacheSizeMaxInternal = [frameCacheSize unsignedIntegerValue];
    FLLog(FLLogLevelDebug, @"Grew frame cache size max to %lu after memory warning for animated image: %@", (unsigned long)self.frameCacheSizeMaxInternal, self);
    
    // Schedule resetting the frame cache size max completely after a while.
    const NSTimeInterval kResetDelay = 3.0;
    [self.weakProxy performSelector:@selector(resetFrameCacheSizeMaxInternal) withObject:nil afterDelay:kResetDelay];
}


- (void)resetFrameCacheSizeMaxInternal
{
    self.frameCacheSizeMaxInternal = FLAnimatedImageFrameCacheSizeNoLimit;
    FLLog(FLLogLevelDebug, @"Reset frame cache size max (current frame cache size: %lu) for animated image: %@", (unsigned long)self.frameCacheSizeCurrent, self);
}


#pragma mark System Memory Warnings Notification Handler

- (void)didReceiveMemoryWarning:(NSNotification *)notification
{
    self.memoryWarningCount++;
    
    // If we were about to grow larger, but got rapped on our knuckles by the system again, cancel.
    [NSObject cancelPreviousPerformRequestsWithTarget:self.weakProxy selector:@selector(growFrameCacheSizeAfterMemoryWarning:) object:@(FLAnimatedImageFrameCacheSizeGrowAfterMemoryWarning)];
    [NSObject cancelPreviousPerformRequestsWithTarget:self.weakProxy selector:@selector(resetFrameCacheSizeMaxInternal) object:nil];
    
    // Go down to the minimum and by that implicitly immediately purge from the cache if needed to not get jettisoned by the system and start producing frames on-demand.
    FLLog(FLLogLevelDebug, @"Attempt setting frame cache size max to %lu (previous was %lu) after memory warning #%lu for animated image: %@", (unsigned long)FLAnimatedImageFrameCacheSizeLowMemory, (unsigned long)self.frameCacheSizeMaxInternal, (unsigned long)self.memoryWarningCount, self);
    self.frameCacheSizeMaxInternal = FLAnimatedImageFrameCacheSizeLowMemory;
    
    // Schedule growing larger again after a while, but cap our attempts to prevent a periodic sawtooth wave (ramps upward and then sharply drops) of memory usage.
    //
    // [mem]^     (2)   (5)  (6)        1) Loading frames for the first time
    //   (*)|      ,     ,    ,         2) Mem warning #1; purge cache
    //      |     /| (4)/|   /|         3) Grow cache size a bit after a while, if no mem warning occurs
    //      |    / |  _/ | _/ |         4) Try to grow cache size back to optimum after a while, if no mem warning occurs
    //      |(1)/  |_/   |/   |__(7)    5) Mem warning #2; purge cache
    //      |__/   (3)                  6) After repetition of (3) and (4), mem warning #3; purge cache
    //      +---------------------->    7) After 3 mem warnings, stay at minimum cache size
    //                            [t]
    //                                  *) The mem high water mark before we get warned might change for every cycle.
    //
    const NSUInteger kGrowAttemptsMax = 2;
    const NSTimeInterval kGrowDelay = 2.0;
    if ((self.memoryWarningCount - 1) <= kGrowAttemptsMax) {
        [self.weakProxy performSelector:@selector(growFrameCacheSizeAfterMemoryWarning:) withObject:@(FLAnimatedImageFrameCacheSizeGrowAfterMemoryWarning) afterDelay:kGrowDelay];
    }
    
    // Note: It's not possible to get the level of a memory warning with a public API: http://stackoverflow.com/questions/2915247/iphone-os-memory-warnings-what-do-the-different-levels-mean/2915477#2915477
}


#pragma mark Image Decoding

// Decodes the image's data and draws it off-screen fully in memory; it's thread-safe and hence can be called on a background thread.
// On success, the returned object is a new `UIImage` instance with the same content as the one passed in.
// On failure, the returned object is the unchanged passed in one; the data will not be predrawn in memory though and an error will be logged.
// First inspired by & good Karma to: https://gist.github.com/steipete/1144242
+ (UIImage *)predrawnImageFromImage:(UIImage *)imageToPredraw
{
    // Always use a device RGB color space for simplicity and predictability what will be going on.
    const CGColorSpaceRef _Nullable colorSpaceDeviceRGBRef = CGColorSpaceCreateDeviceRGB();
    // Early return on failure!
    if (!colorSpaceDeviceRGBRef) {
        FLLog(FLLogLevelError, @"Failed to `CGColorSpaceCreateDeviceRGB` for image %@", imageToPredraw);
        return imageToPredraw;
    }
    
    // Even when the image doesn't have transparency, we have to add the extra channel because Quartz doesn't support other pixel formats than 32 bpp/8 bpc for RGB:
    // kCGImageAlphaNoneSkipFirst, kCGImageAlphaNoneSkipLast, kCGImageAlphaPremultipliedFirst, kCGImageAlphaPremultipliedLast
    // (source: docs "Quartz 2D Programming Guide > Graphics Contexts > Table 2-1 Pixel formats supported for bitmap graphics contexts")
    const size_t numberOfComponents = CGColorSpaceGetNumberOfComponents(colorSpaceDeviceRGBRef) + 1; // 4: RGB + A
    
    // "In iOS 4.0 and later, and OS X v10.6 and later, you can pass NULL if you want Quartz to allocate memory for the bitmap." (source: docs)
    void *_Nullable data = NULL;
    const size_t width = imageToPredraw.size.width;
    const size_t height = imageToPredraw.size.height;
    const size_t bitsPerComponent = CHAR_BIT;
    
    const size_t bitsPerPixel = (bitsPerComponent * numberOfComponents);
    const size_t bytesPerPixel = (bitsPerPixel / BYTE_SIZE);
    const size_t bytesPerRow = (bytesPerPixel * width);
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(imageToPredraw.CGImage);
    // If the alpha info doesn't match to one of the supported formats (see above), pick a reasonable supported one.
    // "For bitmaps created in iOS 3.2 and later, the drawing environment uses the premultiplied ARGB format to store the bitmap data." (source: docs)
    if (alphaInfo == kCGImageAlphaNone || alphaInfo == kCGImageAlphaOnly) {
        alphaInfo = kCGImageAlphaNoneSkipFirst;
    } else if (alphaInfo == kCGImageAlphaFirst) {
        alphaInfo = kCGImageAlphaPremultipliedFirst;
    } else if (alphaInfo == kCGImageAlphaLast) {
        alphaInfo = kCGImageAlphaPremultipliedLast;
    }
    // "The constants for specifying the alpha channel information are declared with the `CGImageAlphaInfo` type but can be passed to this parameter safely." (source: docs)
    bitmapInfo |= alphaInfo;
    
    // Create our own graphics context to draw to; `UIGraphicsGetCurrentContext`/`UIGraphicsBeginImageContextWithOptions` doesn't create a new context but returns the current one which isn't thread-safe (e.g. main thread could use it at the same time).
    // Note: It's not worth caching the bitmap context for multiple frames ("unique key" would be `width`, `height` and `hasAlpha`), it's ~50% slower. Time spent in libRIP's `CGSBlendBGRA8888toARGB8888` suddenly shoots up -- not sure why.
    const CGContextRef _Nullable bitmapContextRef = CGBitmapContextCreate(data, width, height, bitsPerComponent, bytesPerRow, colorSpaceDeviceRGBRef, bitmapInfo);
    CGColorSpaceRelease(colorSpaceDeviceRGBRef);
    // Early return on failure!
    if (!bitmapContextRef) {
        FLLog(FLLogLevelError, @"Failed to `CGBitmapContextCreate` with color space %@ and parameters (width: %zu height: %zu bitsPerComponent: %zu bytesPerRow: %zu) for image %@", colorSpaceDeviceRGBRef, width, height, bitsPerComponent, bytesPerRow, imageToPredraw);
        return imageToPredraw;
    }
    
    // Draw image in bitmap context and create image by preserving receiver's properties.
    CGContextDrawImage(bitmapContextRef, CGRectMake(0.0, 0.0, imageToPredraw.size.width, imageToPredraw.size.height), imageToPredraw.CGImage);
    const CGImageRef _Nullable predrawnImageRef = CGBitmapContextCreateImage(bitmapContextRef);
    UIImage *_Nullable predrawnImage = predrawnImageRef ? [UIImage imageWithCGImage:predrawnImageRef scale:imageToPredraw.scale orientation:imageToPredraw.imageOrientation] : nil;
    CGImageRelease(predrawnImageRef);
    CGContextRelease(bitmapContextRef);
    
    // Early return on failure!
    if (!predrawnImage) {
        FLLog(FLLogLevelError, @"Failed to `imageWithCGImage:scale:orientation:` with image ref %@ created with color space %@ and bitmap context %@ and properties and properties (scale: %f orientation: %ld) for image %@", predrawnImageRef, colorSpaceDeviceRGBRef, bitmapContextRef, imageToPredraw.scale, (long)imageToPredraw.imageOrientation, imageToPredraw);
        return imageToPredraw;
    }
    
    return predrawnImage;
}


#pragma mark - Description

- (NSString *)description
{
    NSString *description = [super description];
    
    description = [description stringByAppendingFormat:@" size=%@", NSStringFromCGSize(self.size)];
    description = [description stringByAppendingFormat:@" frameCount=%lu", (unsigned long)self.frameCount];
    
    return description;
}

#pragma mark - Debugging

#if defined(DEBUG) && DEBUG

- (void)debug_animatedImage:(FLAnimatedImage *)animatedImage didUpdateCachedFrames:(NSIndexSet *)indexesOfFramesInCache
{
    [self.debug_delegate debug_animatedImage:animatedImage didUpdateCachedFrames:indexesOfFramesInCache];
}

- (void)debug_animatedImage:(FLAnimatedImage *)animatedImage didRequestCachedFrame:(NSUInteger)index
{
    [self.debug_delegate debug_animatedImage:animatedImage didRequestCachedFrame:index];
}

- (CGFloat)debug_animatedImagePredrawingSlowdownFactor:(FLAnimatedImage *)animatedImage
{
    if ([self.debug_delegate respondsToSelector:@selector(debug_animatedImagePredrawingSlowdownFactor:)]) {
        return [self.debug_delegate debug_animatedImagePredrawingSlowdownFactor:self];
    }
    return 0;
}

#endif



@end

#pragma mark - Logging

@implementation FLAnimatedImage (Logging)

static void (^_logBlock)(NSString *logString, FLLogLevel logLevel) = nil;
static FLLogLevel _logLevel;

+ (void)setLogBlock:(void (^_Nullable)(NSString *logString, FLLogLevel logLevel))logBlock logLevel:(FLLogLevel)logLevel
{
    _logBlock = [logBlock copy];
    _logLevel = logLevel;
}

+ (void)logStringFromBlock:(NSString *(^_Nullable)(void))stringBlock withLevel:(FLLogLevel)level
{
    if (level <= _logLevel && _logBlock && stringBlock) {
        _logBlock(stringBlock(), level);
    }
}

@end
