//
//  AVAnimatorView.m
//
//  Created by Moses DeJong on 3/18/09.
//
//  License terms defined in License.txt.

#import "AVAnimatorView.h"

#import <QuartzCore/QuartzCore.h>

#import "AVAnimatorMedia.h"

// private properties declaration for AVAnimatorLayer class
#import "AVAnimatorLayerPrivate.h"

#import "AutoPropertyRelease.h"

// AVAnimatorLayer class

@implementation AVAnimatorLayer

// public properties

@synthesize layerObj = m_layerObj;
@synthesize mediaObj = m_mediaObj;
@synthesize imageObj = m_imageObj;

- (void) dealloc {
  [self attachMedia:nil];
  [AutoPropertyRelease releaseProperties:self thisClass:AVAnimatorLayer.class];  
  [super dealloc];
}

// static ctor

+ (AVAnimatorLayer*) aVAnimatorLayer:(CALayer*)layer
{
  NSAssert(layer, @"layer");
  AVAnimatorLayer *obj = [[AVAnimatorLayer alloc] init];
  [obj autorelease];
  obj.layerObj = layer;
  return obj;  
}

- (id) init
{
  if (self = [super init]) {
    // No specific defaults are needed
  }
  return self;
}

// This method is invoked once resources have been loaded by the media

- (void) mediaDidLoad
{
  NSAssert(self.media, @"media is nil");
  NSAssert(self.media.frameDecoder, @"frameDecoder is nil");
	return;
}

- (void) attachMedia:(AVAnimatorMedia*)inMedia
{
  if (inMedia == nil) {
    // Detach case
    
    [self.mediaObj detachFromRenderer:self];
    self.mediaObj = nil;
    self.imageObj = nil;
    return;
  }
  
  [self.mediaObj detachFromRenderer:self];
  self.mediaObj = inMedia;
  self.imageObj = nil;
  [self.mediaObj attachToRenderer:self];
}

// Implement read-only property for use outside this class

- (AVAnimatorMedia*) media
{
  return self->m_mediaObj;
}

- (CALayer*) layer
{
  return self->m_layerObj;
}

// This method is invoked as part of the AVAnimatorMediaRendererProtocol when
// a new frame image is generated by the media. Note that we only need to
// set the contents of the CALayer, rendering of the CGImageRef is handled
// by the CALayer class.

- (void) setImage:(UIImage*)image
{
  NSAssert(image, @"image");
  self.imageObj = image;
  CGImageRef cgImage = image.CGImage;
  self.layer.contents = (id) cgImage;
}

- (UIImage*) image
{
  return self.imageObj;
}

@end
