//
//  FLAnimatedWebPImageDecoder.h
//  FLAnimatedImage
//
//  Created by Sih Ou-Yang on 2023/4/10.
//  Copyright © 2023 com.flipboard. All rights reserved.
//

#import "FLAnimatedWebPImageFrame.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLAnimatedWebPImageDecoder : NSObject

@property(nonatomic) CGSize imageSize;
@property(nonatomic) NSUInteger loopCount;
@property(nonatomic) size_t frameCount;

@property(nonatomic) NSArray<FLAnimatedWebPImageFrame *> *imageFrames;

- (instancetype)initWithData:(NSData *)data;

- (UIImage * _Nullable)decodedImageWithData:(NSData * _Nullable)data;

@end

NS_ASSUME_NONNULL_END
