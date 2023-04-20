//
//  FLAnimatedBuiltInWebPDataSource.h
//  Facebook
//
//  Created by Ben Hiller.
//  Copyright (c) 2014-2015 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <FLAnimatedImageFrameDataSource.h>

@interface FLAnimatedSystemWebPDataSource : NSObject <FLAnimatedImageFrameDataSource>

- (instancetype)initWithData:(NSData *)data;

@end
