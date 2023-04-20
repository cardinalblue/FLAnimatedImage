#import "FLAnimatedBuiltInWebPDataSource.h"
#import "FLAnimatedWebPImageDecoder.h"
#import "UIImage+Extension.h"

const CGFloat kScale = 1.0;

@interface FLAnimatedBuiltInWebPDataSource ()

@property(nonatomic) FLAnimatedWebPImageDecoder *decoder;

@end

@implementation FLAnimatedBuiltInWebPDataSource

- (instancetype)initWithData:(NSData *)data {
    self = [super init];
    if (self) {
        _decoder = [[FLAnimatedWebPImageDecoder alloc] initWithData:data];
    }
    return self;
}

- (UIImage *)imageAtIndex:(NSUInteger)index {
    UIImage *image = [self.decoder imageFrames][index].image;
    return [UIImage predrawnImageFromImage:image];
}

- (BOOL)frameRequiresBlendingWithPreviousFrame:(NSUInteger)index {
    return NO;
}

- (UIImage *)blendImage:(UIImage *)image atIndex:(NSUInteger)index withPreviousImage:(UIImage *)previousImage {
    return image;
}

@end
