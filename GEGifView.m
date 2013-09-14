//
//  GEGifView.m
//
//  Created by godera on 3/28/13.
//  Copyright (c) 2013. All rights reserved.
//

#import "GEGifView.h"
#import <ImageIO/ImageIO.h>
#import <QuartzCore/CoreAnimation.h>

@interface GEGifView() {
    CADisplayLink* _displayLink;
    
    NSMutableArray* _frameImages;//CGImageRefs
    NSMutableArray* _frameDelayTimes;
    NSMutableArray* _frameStartTimes;//the 0 frame corresponds to time point 0.
    NSInteger _comparedFrameIndex;
    NSTimeInterval _currentTimePoint;//compared to item in _frameStartTimes
    
    CGFloat _totalTime;         // seconds
    CGFloat _width;
    CGFloat _height;
    
    NSInteger _decreasingCount;
}

@end


@implementation GEGifView

- (void)dealloc
{
    [_data release];
    [_filePath release];
    [_fileName release];

    [_image release];
    [_runLoopMode release];
    
    [_displayLink release];
    
    [_frameImages release];
    [_frameDelayTimes release];
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
        
        _frameImages = [NSMutableArray new];
        _frameDelayTimes = [NSMutableArray new];
        _frameStartTimes = [NSMutableArray new];
        _comparedFrameIndex = 0;
        
        _totalTime = 0;
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
    
    CGImageSourceRef gifSource = CGImageSourceCreateWithData((CFDataRef)_data, NULL);
    
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
    
    NSString *filePath = [[NSBundle mainBundle]pathForResource:_fileName ofType:nil];
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


/*
 * @brief gets gif information
 */
- (void)getFrameInfosFromGifSource:(CGImageSourceRef)gifSource
{
    // init
    _totalTime = 0;
    [_frameImages removeAllObjects];
    [_frameDelayTimes removeAllObjects];
    [_frameStartTimes removeAllObjects];
    
    // get frame count
    size_t frameCount = CGImageSourceGetCount(gifSource);
    for (size_t i = 0; i < frameCount; ++i) {
        // get each frame
        CGImageRef frame = CGImageSourceCreateImageAtIndex(gifSource, i, NULL);
        [_frameImages addObject:(id)frame];
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
        [_frameDelayTimes addObject:aDelayTime];
        
        _totalTime += [aDelayTime floatValue];

        CFRelease(dict);
    }
    
    // get frame start times
    [_frameStartTimes addObject:@(0)];
    CGFloat currentFrameStartTime = 0;
    for (id aDelayTime in _frameDelayTimes) {
        currentFrameStartTime += [aDelayTime floatValue];
        [_frameStartTimes addObject:@(currentFrameStartTime)];
    }

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
    return _totalTime;
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


