//
//  FLAnimatedImage+Extension.m
//  FLAnimatedImage
//
//  Created by Sih Ou-Yang on 2023/4/15.
//  Copyright © 2023 com.flipboard. All rights reserved.
//

#import "FLAnimatedImage+Extension.h"
#import <FLAnimatedImage/FLAnimatedImage+GIF.h>
#import <FLAnimatedImage/FLAnimatedImage+WebP.h>

#pragma mark - Private helper

@interface NSData (ImageFormat)

- (BOOL)isWebP;
- (BOOL)isGIF;

@end

@implementation NSData (ImageFormat)

- (BOOL)isWebP {
    unsigned char riffNumber[] = {0x52, 0x49, 0x46, 0x46}; // "RIFF" in ASCII
    unsigned char webPNumber[] = {0x57, 0x45, 0x42, 0x50}; // "WEBP" in ASCII

    // Get the first few bytes of the data
    unsigned char buffer[4];
    if (self.length >= 4) {
        [self getBytes:&buffer length:4];
    } else {
        // Invalid image data
        return NO;
    }

    // Compare the buffer with the magic numbers to determine the image format
    if (memcmp(buffer, riffNumber, sizeof(riffNumber)) == 0 && self.length > 12) {
        // Check RIFF first then check WEBP
        NSData *splitData = [self subdataWithRange:NSMakeRange(8, 4)];
        unsigned char newBuffer[4];
        [splitData getBytes:&newBuffer length:4];

        if (memcmp(newBuffer, webPNumber, sizeof(webPNumber)) == 0) {
            return YES;
        }
    }

    return NO;
}

- (BOOL)isGIF {
    unsigned char gifMagicNumber[] = {0x47, 0x49, 0x46}; // "GIF" in ASCII
    // Get the first few bytes of the data
    unsigned char buffer[4];
    if (self.length >= 4) {
        [self getBytes:&buffer length:4];
    } else {
        // Invalid image data
        return NO;
    }

    // Compare the buffer with the magic numbers to determine the image format
    if (memcmp(buffer, gifMagicNumber, sizeof(gifMagicNumber)) == 0) {
        return YES;
    }

    return NO;
}

@end

#pragma mark - FLAnimatedImage Extension

@implementation FLAnimatedImage (Extension)

+ (FLAnimatedImage *)animatedImageWithData:(NSData *)data {
    if (data.isGIF) {
        return [FLAnimatedImage animatedImageWithGIFData:data];
    } else if (data.isWebP) {
        return [FLAnimatedImage animatedImageWithWebPData:data decodeType:WebPDecodeLib];
    } else {
        return nil;
    }
}

@end
