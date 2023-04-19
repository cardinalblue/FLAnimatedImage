//
//  WebPImageDecoder.h
//  FLAnimatedImage
//
//  Created by Sih Ou-Yang on 2023/4/10.
//  Copyright © 2023 com.flipboard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ImageFrame: NSObject

@property (nonatomic) UIImage *image;
@property (nonatomic) NSTimeInterval duration;

- (instancetype)initWithImage:(UIImage *)image duration:(NSTimeInterval)duration;

@end

@interface WebPImageDecoder : NSObject

@property(nonatomic) CGSize imageSize;
@property(nonatomic) NSUInteger loopCount;
@property(nonatomic) size_t frameCount;

@property(nonatomic) NSArray<ImageFrame *> *imageFrames;

- (instancetype)initWithData:(NSData *)data;

- (UIImage * _Nullable)decodedImageWithData:(NSData * _Nullable)data;

@end

NS_ASSUME_NONNULL_END
