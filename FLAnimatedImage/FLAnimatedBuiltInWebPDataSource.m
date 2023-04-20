#import "FLAnimatedBuiltInWebPDataSource.h"
#import "FLAnimatedWebPImageDecoder.h"
#import "UIImage+Extension.h"

const CGFloat kScale = 1.0;

@interface FLAnimatedBuiltInWebPDataSource ()

@property(nonatomic) FLAnimatedWebPImageDecoder *decoder;

@end

@implementation FLAnimatedBuiltInWebPDataSource

- (instancetype)initWithDecoder:(FLAnimatedWebPImageDecoder *)decoder {
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
