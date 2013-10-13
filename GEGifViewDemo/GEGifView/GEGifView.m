//
//  GEGifView.h
//
//  Created by godera@yeah.net on 9/14/13.
//  Copyright (c) 2013. All rights reserved.
//
//  QQ: 719181178
/* supports both gif and image, based on SvGifView and OLImageView */
/* MRC */

#define KEY_FRAME_IMAGES @"KEY_FRAME_IMAGES"
#define KEY_FRAME_START_TIMES @"KEY_FRAME_START_TIMES"
#define KEY_GE_MEDIA_TYPE @"KEY_GE_MEDIA_TYPE"

#import "GEGifView.h"
#import <ImageIO/ImageIO.h>
#import <QuartzCore/CoreAnimation.h>

typedef enum {
    GEMediaType_GIF = 0,
    GEMediaType_IMAGE,
}GEMediaType;

@interface GEGifView()
{
    NSInteger _comparedFrameIndex;
    NSTimeInterval _currentTimePoint; // compared to item in _frameStartTimes
    
    CGFloat _width;
    CGFloat _height;
    
    NSInteger _decreasingCount;
    
    GEMediaType _mediaType;
    BOOL _canRestart;
    CADisplayLink* _displayLink;
}
@property (copy, nonatomic) NSArray* frameImages; // CGImageRefs
@property (copy, nonatomic) NSArray* frameStartTimes; // the 0 frame corresponds to time point 0.

@end


@implementation GEGifView

- (void)dealloc
{
    [_data release];
    [_filePath release];
    [_fileName release];

    [_runLoopMode release];
    
    [_frameImages release];
    [_frameStartTimes release];
    
    [super dealloc];
}

-(void)willMoveToWindow:(UIWindow *)newWindow
{
    if (newWindow == nil) // at the moment the method like viewWillDisappear in view controller
    {
        if (_isAnimating)
        {
            [self stop];
            _canRestart = YES;
        }
    }
    else // at the moment the method like viewWillAppear in view controller
    {
        if (_canRestart)
        {
            _canRestart = NO;
            [self start];
        }
    }
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
        self.userInteractionEnabled = NO;
        self.contentMode = UIViewContentModeScaleAspectFit;
        
        _runLoopMode = NSDefaultRunLoopMode;
        
        _clearWhenStop = YES;
        
        _comparedFrameIndex = 0;
        
        _width = 0;
        _height = 0;
        
        _repeatCount = NSUIntegerMax;
    }
    return self;
}

-(void)setData:(NSData *)data
{
    NSData* temp = [data copy];
    [_data release];
    _data = temp;
    
    CGImageSourceRef gifSource = CGImageSourceCreateWithData((CFDataRef)data, NULL);
    
    [self getFrameInfosFromGifSource:gifSource];
    
    if (gifSource) {
        CFRelease(gifSource);
    }
}

-(void)setFileName:(NSString *)fileName
{
    NSString* temp = [fileName copy];
    [_fileName release];
    _fileName = temp;
    
    NSString *filePath = [[NSBundle mainBundle]pathForResource:fileName ofType:nil];
    NSURL* fileURL = [NSURL fileURLWithPath:filePath];
    CGImageSourceRef gifSource = CGImageSourceCreateWithURL((CFURLRef)fileURL, NULL);
    
    [self getFrameInfosFromGifSource:gifSource];
    
    if (gifSource) {
        CFRelease(gifSource);
    }
}

-(void)setFilePath:(NSString *)filePath
{
    NSString* temp = [filePath copy];
    [_filePath release];
    _filePath = temp;
    
    NSURL* fileURL = [NSURL fileURLWithPath:filePath];
    CGImageSourceRef gifSource = CGImageSourceCreateWithURL((CFURLRef)fileURL, NULL);
    
    [self getFrameInfosFromGifSource:gifSource];
    
    if (gifSource) {
        CFRelease(gifSource);
    }
}

- (void)setFrameItems:(NSDictionary *)frameItems
{
    self.frameImages = [frameItems objectForKey:KEY_FRAME_IMAGES];
    self.frameStartTimes = [frameItems objectForKey:KEY_FRAME_START_TIMES];
    _mediaType = [[frameItems objectForKey:KEY_GE_MEDIA_TYPE] integerValue];
}

-(NSDictionary *)frameItems
{
    return @{KEY_FRAME_IMAGES:_frameImages, KEY_FRAME_START_TIMES:_frameStartTimes, KEY_GE_MEDIA_TYPE:@(_mediaType)};
}


/*
 * @brief gets gif information
 */
- (void)getFrameInfosFromGifSource:(CGImageSourceRef)gifSource
{
    // get frame count
    size_t frameCount = CGImageSourceGetCount(gifSource);
    
    if (frameCount <= 1)
    {
        _mediaType = GEMediaType_IMAGE;
        CGImageRef frame = CGImageSourceCreateImageAtIndex(gifSource, 0, NULL);
        self.layer.contents = (id)frame;
        CGImageRelease(frame);
        
        // assign values
        self.frameImages = @[(id)frame];
        self.frameStartTimes = @[@(0),@(CGFLOAT_MAX)];
        return;
    }
    
    _mediaType = GEMediaType_GIF;
    // init
    NSMutableArray* frameImages = [[NSMutableArray new] autorelease];
    NSMutableArray* frameStartTimes = [[NSMutableArray new] autorelease];
    NSMutableArray* frameDelayTimes = [[NSMutableArray new] autorelease];
    
    for (size_t i = 0; i < frameCount; ++i)
    {
        // get each frame
        CGImageRef frame = CGImageSourceCreateImageAtIndex(gifSource, i, NULL);
        [frameImages addObject:(id)frame];
        CGImageRelease(frame);
        
        // get gif info with each frame
        NSDictionary *dict = (NSDictionary*)CGImageSourceCopyPropertiesAtIndex(gifSource, i, NULL);
        GELOG_GIF(@"kCGImagePropertyGIFDictionary %ld = %@", i,[dict objectForKey:(NSString*)kCGImagePropertyGIFDictionary]);
        
        // get gif size
        _width = [[dict objectForKey:(NSString*)kCGImagePropertyPixelWidth] floatValue];
        _height = [[dict objectForKey:(NSString*)kCGImagePropertyPixelHeight] floatValue];
        
        // kCGImagePropertyGIFDictionary中kCGImagePropertyGIFDelayTime，kCGImagePropertyGIFUnclampedDelayTime值是一样的
        NSDictionary *gifDict = [dict objectForKey:(NSString*)kCGImagePropertyGIFDictionary];
        
        id aDelayTime = [gifDict objectForKey:(NSString*)kCGImagePropertyGIFDelayTime];
        [frameDelayTimes addObject:aDelayTime];
        
        CFRelease(dict);
    }
    
    // get frame start times
    [frameStartTimes addObject:@(0)];
    CGFloat currentFrameStartTime = 0;
    for (id aDelayTime in frameDelayTimes)
    {
        currentFrameStartTime += [aDelayTime floatValue];
        [frameStartTimes addObject:@(currentFrameStartTime)];
    }
    
    // assign values
    self.frameImages = frameImages;
    self.frameStartTimes = frameStartTimes;
}

- (void)changeFrame:(CADisplayLink*)displayLink
{
    _currentTimePoint += displayLink.duration;
    
    GELOG_GIF(@"time point = Current:%f--%f:Compared",_currentTimePoint,[_frameStartTimes[_comparedFrameIndex] doubleValue]);
    
    if (_currentTimePoint >= [_frameStartTimes[_comparedFrameIndex] doubleValue])
    {
        if (_comparedFrameIndex >= _frameImages.count) // one loop
        {
            if (_repeatCount != NSUIntegerMax)
            {
                _decreasingCount --;
                if (_decreasingCount == 0)
                {
                    [self stop];
                    return;
                }
            }
            _comparedFrameIndex = 0;
            _currentTimePoint = 0;
        }
        self.layer.contents = _frameImages[_comparedFrameIndex];
        _comparedFrameIndex ++; // next compared frame index
    }
}

- (void)start
{
    if ([self isPreparedToPlay] == NO)
    {
        return;
    }
    
    if (_mediaType == GEMediaType_IMAGE)
    {
        self.layer.contents = _frameImages[0];
        return;
    }
    
    if (_displayLink.paused == YES) // recover from pause state
    {
        _displayLink.paused = NO;
    }
    else // a new start
    {
        _currentTimePoint = 0;
        _decreasingCount = _repeatCount;
        
        self.layer.contents = _frameImages[0];
        _comparedFrameIndex = 1;
        
        [_displayLink invalidate];
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(changeFrame:)];
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:_runLoopMode];
    }
    
    _isAnimating = YES;
}

- (void)stop
{
    if (_mediaType == GEMediaType_IMAGE)
    {
        if (_clearWhenStop)
        {
            self.layer.contents = nil;
        }
        return;
    }
    
    [_displayLink invalidate];
    _displayLink = nil;
    
    if (_clearWhenStop)
    {
        self.layer.contents = nil;
    }
    
    _isAnimating = NO;
}

- (void)pause
{
    if (_mediaType == GEMediaType_IMAGE)
    {
        return;
    }
    
    _displayLink.paused = YES;
    _isAnimating = NO;
}

-(CGFloat)duration
{
    return [[_frameStartTimes lastObject] floatValue];
}

-(void)setImage:(UIImage *)image
{
    self.layer.contents = (id)[image CGImage];
}

-(UIImage *)image
{
    return [UIImage imageWithCGImage:(CGImageRef)self.layer.contents];
}

-(BOOL)isPreparedToPlay
{
    return self.frameImages && self.frameStartTimes;
}

-(NSString *)description
{
    return [NSString stringWithFormat:@"fileName = %@, filePath = %@, repeatCount = %ld, frameCount = %lu",_fileName,_filePath,(long)_repeatCount,(unsigned long)_frameImages.count];
}

@end


