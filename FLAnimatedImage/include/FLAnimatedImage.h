//
//  FLAnimatedImage.h
//  Flipboard
//
//  Created by Raphael Schaad on 7/8/13.
//  Copyright (c) Flipboard. All rights reserved.
//


#import <UIKit/UIKit.h>

// Allow user classes conveniently just importing one header.
#import "FLAnimatedImageView.h"
#import "FLAnimatedImageData.h"
#import "FLAnimatedImageFrameCache.h"

#ifndef NS_DESIGNATED_INITIALIZER
    #if __has_attribute(objc_designated_initializer)
        #define NS_DESIGNATED_INITIALIZER __attribute((objc_designated_initializer))
    #else
        #define NS_DESIGNATED_INITIALIZER
    #endif
#endif
@protocol FLAnimatedImageFrameDataSource;
#if defined(DEBUG) && DEBUG
@protocol FLAnimatedImageDebugDelegate;
#endif

#if defined(DEBUG) && DEBUG
@protocol FLAnimatedImageDebugDelegate <NSObject>
@optional
- (void)debug_animatedImage:(FLAnimatedImage *)animatedImage didUpdateCachedFrames:(NSIndexSet *)indexesOfFramesInCache;
- (void)debug_animatedImage:(FLAnimatedImage *)animatedImage didRequestCachedFrame:(NSUInteger)index;
- (CGFloat)debug_animatedImagePredrawingSlowdownFactor:(FLAnimatedImage *)animatedImage;
@end
#endif

extern const NSTimeInterval kFLAnimatedImageDelayTimeIntervalMinimum;

//
//  An `FLAnimatedImage`'s job is to deliver frames in a highly performant way and works in conjunction with `FLAnimatedImageView`.
//  It subclasses `NSObject` and not `UIImage` because it's only an "image" in the sense that a sea lion is a lion.
//  It tries to intelligently choose the frame cache size depending on the image and memory situation with the goal to lower CPU usage for smaller ones, lower memory usage for larger ones and always deliver frames for high performant play-back.
//  Note: `posterImage`, `size`, `loopCount`, `delayTimes` and `frameCount` don't change after successful initialization.
//
@interface FLAnimatedImage : NSObject

@property (nonatomic, strong, readonly) UIImage *posterImage; // Guaranteed to be loaded; usually equivalent to `-imageLazilyCachedAtIndex:0`
@property (nonatomic, assign, readonly) CGSize size; // The `.posterImage`'s `.size`

@property (nonatomic, assign, readonly) NSUInteger loopCount; // "The number of times to repeat an animated sequence." according to ImageIO (note the slightly different definition to Netscape 2.0 Loop Extension); 0 means repeating the animation forever
@property (nonatomic, strong, readonly) NSDictionary *delayTimesForIndexes; // Of type `NSTimeInterval` boxed in `NSNumber`s
@property (nonatomic, assign, readonly) NSUInteger frameCount; // Number of valid frames; equal to `[.delayTimes count]`

@property (nonatomic, assign, readonly) NSUInteger frameCacheSizeCurrent; // Current size of intelligently chosen buffer window; can range in the interval [1..frameCount]
@property (nonatomic, assign) NSUInteger frameCacheSizeMax; // Allow to cap the cache size; 0 means no specific limit (default)

@property (nonatomic, strong, readonly) FLAnimatedImageData *animatedImageData;

@property (nonatomic, strong, readonly) id<FLAnimatedImageFrameDataSource> frameDataSource;

// Intended to be called from main thread synchronously; will return immediately.
// If the result isn't cached, will return `nil`; the caller should then pause playback, not increment frame counter and keep polling.
// After an initial loading time, depending on `frameCacheSize`, frames should be available immediately from the cache.
- (UIImage *)imageLazilyCachedAtIndex:(NSUInteger)index;


#if defined(DEBUG) && DEBUG
@property (nonatomic, weak) id<FLAnimatedImageDebugDelegate> debug_delegate;
@property (nonatomic, strong) NSMutableDictionary *debug_info; // To track arbitrary data (e.g. original URL, loading durations, cache hits, etc.)
#endif

@end

typedef NS_ENUM(NSUInteger, FLLogLevel) {
    FLLogLevelNone = 0,
    FLLogLevelError,
    FLLogLevelWarn,
    FLLogLevelInfo,
    FLLogLevelDebug,
    FLLogLevelVerbose
};

@interface FLAnimatedImage (Logging)

+ (void)setLogBlock:(void (^)(NSString *logString, FLLogLevel logLevel))logBlock logLevel:(FLLogLevel)logLevel;
+ (void)logStringFromBlock:(NSString *(^)(void))stringBlock withLevel:(FLLogLevel)level;

@end

@interface FLAnimatedImage (Extension)

+ (FLAnimatedImage * _Nullable)animatedImageWithData:(NSData *)data;

@end

@interface FLAnimatedImage (GIF)

+ (FLAnimatedImage *)animatedImageWithGIFData:(NSData *)data;

@end

@interface FLAnimatedImage (Internal)

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
@end

typedef NS_ENUM(NSInteger, WebPDecodeType) {
    WebPDecodeSystem, // use the iOS 14 built-in feature to decode webp
    WebPDecodeLibWebP
};

@interface FLAnimatedImage (WebP)

+ (FLAnimatedImage *)animatedImageWithWebPData:(NSData *)data decodeType:(WebPDecodeType)type;

@end

// Try to detect and import CocoaLumberjack in all scenarious (library versions, way of including it, CocoaPods versions, etc.).
#if FLLumberjackIntegrationEnabled
    #if defined(__has_include)
        #if __has_include("<CocoaLumberjack/CocoaLumberjack.h>")
            #import <CocoaLumberjack/CocoaLumberjack.h>
        #elif __has_include("CocoaLumberjack.h")
            #import "CocoaLumberjack.h"
        #elif __has_include("<CocoaLumberjack/DDLog.h>")
            #import <CocoaLumberjack/DDLog.h>
        #elif __has_include("DDLog.h")
            #import "DDLog.h"
        #endif
    #elif defined(COCOAPODS_POD_AVAILABLE_CocoaLumberjack) || defined(__POD_CocoaLumberjack)
        #if COCOAPODS_VERSION_MAJOR_CocoaLumberjack == 2
            #import <CocoaLumberjack/CocoaLumberjack.h>
        #else
            #import <CocoaLumberjack/DDLog.h>
        #endif
    #endif

    #if defined(DDLogError) && defined(DDLogWarn) && defined(DDLogInfo) && defined(DDLogDebug) && defined(DDLogVerbose)
        #define FLLumberjackAvailable
    #endif
#endif

#if FLLumberjackIntegrationEnabled && defined(FLLumberjackAvailable)
    // Use a custom, global (not per-file) log level for this library.
    extern int flAnimatedImageLogLevel;
    #if defined(LOG_OBJC_MAYBE) // CocoaLumberjack 1.x
        #define FLLogError(frmt, ...)   LOG_OBJC_MAYBE(LOG_ASYNC_ERROR,   flAnimatedImageLogLevel, LOG_FLAG_ERROR,   0, frmt, ##__VA_ARGS__)
        #define FLLogWarn(frmt, ...)    LOG_OBJC_MAYBE(LOG_ASYNC_WARN,    flAnimatedImageLogLevel, LOG_FLAG_WARN,    0, frmt, ##__VA_ARGS__)
        #define FLLogInfo(frmt, ...)    LOG_OBJC_MAYBE(LOG_ASYNC_INFO,    flAnimatedImageLogLevel, LOG_FLAG_INFO,    0, frmt, ##__VA_ARGS__)
        #define FLLogDebug(frmt, ...)   LOG_OBJC_MAYBE(LOG_ASYNC_DEBUG,   flAnimatedImageLogLevel, LOG_FLAG_DEBUG,   0, frmt, ##__VA_ARGS__)
        #define FLLogVerbose(frmt, ...) LOG_OBJC_MAYBE(LOG_ASYNC_VERBOSE, flAnimatedImageLogLevel, LOG_FLAG_VERBOSE, 0, frmt, ##__VA_ARGS__)
    #else // CocoaLumberjack 2.x
        #define FLLogError(frmt, ...)   LOG_MAYBE(NO,                flAnimatedImageLogLevel, DDLogFlagError,   0, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
        #define FLLogWarn(frmt, ...)    LOG_MAYBE(LOG_ASYNC_ENABLED, flAnimatedImageLogLevel, DDLogFlagWarning, 0, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
        #define FLLogInfo(frmt, ...)    LOG_MAYBE(LOG_ASYNC_ENABLED, flAnimatedImageLogLevel, DDLogFlagInfo,    0, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
        #define FLLogDebug(frmt, ...)   LOG_MAYBE(LOG_ASYNC_ENABLED, flAnimatedImageLogLevel, DDLogFlagDebug,   0, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
        #define FLLogVerbose(frmt, ...) LOG_MAYBE(LOG_ASYNC_ENABLED, flAnimatedImageLogLevel, DDLogFlagVerbose, 0, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
    #endif
#else
    #if FLDebugLoggingEnabled && DEBUG
        // CocoaLumberjack is disabled or not available, but we want to fallback to regular logging (debug builds only).
        #define FLLog(...) NSLog(__VA_ARGS__)
    #else
        // No logging at all.
        #define FLLog(...) ((void)0)
    #endif
    #define FLLogError(...)   FLLog(__VA_ARGS__)
    #define FLLogWarn(...)    FLLog(__VA_ARGS__)
    #define FLLogInfo(...)    FLLog(__VA_ARGS__)
    #define FLLogDebug(...)   FLLog(__VA_ARGS__)
    #define FLLogVerbose(...) FLLog(__VA_ARGS__)
#endif
