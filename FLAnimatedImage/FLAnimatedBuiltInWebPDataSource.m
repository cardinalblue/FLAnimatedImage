#import "FLAnimatedBuiltInWebPDataSource.h"
#import "WebPImageDecoder.h"
#import "UIImage+Extension.h"

const CGFloat kScale = 1.0;

@interface FLAnimatedBuiltInWebPDataSource ()

@property(nonatomic) WebPImageDecoder *decoder;

@end

@implementation FLAnimatedBuiltInWebPDataSource

- (instancetype)initWithDecoder:(WebPImageDecoder *)decoder {
    self = [super init];
    if (self) {
        _decoder = decoder;
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
