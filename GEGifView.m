//
//  GEGifView.m
//
//  Created by godera on 3/28/13.
//  Copyright (c) 2013. All rights reserved.
//

#import "GEGifView.h"
#import <ImageIO/ImageIO.h>
#import <QuartzCore/CoreAnimation.h>

@interface GEGifView()
{
    NSInteger _comparedFrameIndex;
    NSTimeInterval _currentTimePoint;//compared to item in _frameStartTimes
    
    CGFloat _width;
    CGFloat _height;
    
    NSInteger _decreasingCount;
}
@property (copy, nonatomic) NSArray* frameImages;//CGImageRefs
@property (copy, nonatomic) NSArray* frameStartTimes;//the 0 frame corresponds to time point 0.
@property (assign, nonatomic) CADisplayLink* displayLink;

@end


@implementation GEGifView
@synthesize frameItems = _frameItems;

- (void)dealloc
{
    [_data release];
    [_filePath release];
    [_fileName release];
    [_frameItems release];

    [_image release];
    [_runLoopMode release];
    
    [_displayLink release];
    
    [_frameImages release];
    [_frameStartTimes release];
    
    [super dealloc];
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
    NSDictionary* temp = [frameItems copy];
    [_frameItems release];
    _frameItems = temp;
    
    self.frameImages = [frameItems objectForKey:KEY_FRAME_IMAGES];
    self.frameStartTimes = [frameItems objectForKey:KEY_FRAME_START_TIMES];
}

-(NSDictionary *)frameItems
{
    return @{KEY_FRAME_IMAGES:_frameImages, KEY_FRAME_START_TIMES:_frameStartTimes};
}


/*
 * @brief gets gif information
 */
- (void)getFrameInfosFromGifSource:(CGImageSourceRef)gifSource
{
    // init
    NSMutableArray* frameImages = [[NSMutableArray new] autorelease];
    NSMutableArray* frameStartTimes = [[NSMutableArray new] autorelease];
    NSMutableArray* frameDelayTimes = [[NSMutableArray new] autorelease];
    
    // get frame count
    size_t frameCount = CGImageSourceGetCount(gifSource);
    for (size_t i = 0; i < frameCount; ++i) {
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
    for (id aDelayTime in frameDelayTimes) {
        currentFrameStartTime += [aDelayTime floatValue];
        [frameStartTimes addObject:@(currentFrameStartTime)];
    }
    
    // assign values
    self.frameImages = frameImages;
    self.frameStartTimes = frameStartTimes;
    
}

- (void)changeFrame:(CADisplayLink*)displayLink
{
    GELOG_GIF(@"compared time point = %f",[_frameStartTimes[_comparedFrameIndex] doubleValue]);
    GELOG_GIF(@"current time point = %f",displayLink.duration);
    
    _currentTimePoint += displayLink.duration;
    if (_currentTimePoint >= [_frameStartTimes[_comparedFrameIndex] doubleValue]) {
        if (_comparedFrameIndex >= _frameImages.count) {//one loop
            if (_repeatCount != NSUIntegerMax) {
                _decreasingCount --;
                if (_decreasingCount == 0) {
                    [self stop];
                    return;
                }
            }
            _comparedFrameIndex = 0;
            _currentTimePoint = 0;
        }
        self.layer.contents = _frameImages[_comparedFrameIndex];
        _comparedFrameIndex ++;//next compared frame index
    }
}

- (void)start
{
    if (_displayLink.paused == YES) {// recover from pause state
        _displayLink.paused = NO;
    }else{// a new start
        _currentTimePoint = 0;
        _decreasingCount = _repeatCount;
        
        self.layer.contents = _frameImages[0];
        _comparedFrameIndex = 1;
        
        [_displayLink invalidate];
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(changeFrame:)];
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:_runLoopMode];
    }
}

- (void)stop
{
    [_displayLink invalidate];
    _displayLink = nil;
    
    if (_clearWhenStop) {
        self.layer.contents = nil;
    }
}

- (void)pause
{
    _displayLink.paused = YES;
}

-(CGFloat)duration
{
    return [[_frameStartTimes lastObject] floatValue];
}

-(void)setImage:(UIImage *)image
{
    UIImage* temp = [image retain];
    [_image release];
    _image = temp;
    
    self.layer.contents = (id)[image CGImage];
}

-(NSString *)description
{
    return [NSString stringWithFormat:@"fileName = %@, filePath = %@, repeatCount = %d, frameCount = %d",_fileName,_filePath,_repeatCount,_frameImages.count];
}

@end


