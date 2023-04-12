//
//  FLAnimatedImage+Extension.h
//  FLAnimatedImage
//
//  Created by Sih Ou-Yang on 2023/4/15.
//  Copyright © 2023 com.flipboard. All rights reserved.
//

#import <FLAnimatedImage/FLAnimatedImage.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLAnimatedImage (Extension)

+ (FLAnimatedImage * _Nullable)animatedImageWithData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
