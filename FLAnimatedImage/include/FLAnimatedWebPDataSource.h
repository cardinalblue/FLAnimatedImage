//
//  FLAnimatedWebPDataSource.h
//  Facebook
//
//  Created by Ben Hiller.
//  Copyright (c) 2014-2015 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <FLAnimatedImageFrameDataSource.h>

@class WebPImageDecoder;

@interface FLAnimatedWebPDataSource : NSObject <FLAnimatedImageFrameDataSource>

- (instancetype)initWithDecoder:(WebPImageDecoder *)decoder;

@end
