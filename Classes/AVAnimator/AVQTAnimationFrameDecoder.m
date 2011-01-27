//
//  AVQTAnimationFrameDecoder.m
//
//  Created by Moses DeJong on 12/30/10.
//
//  License terms defined in License.txt.

#import "AVQTAnimationFrameDecoder.h"

#import "CGFrameBuffer.h"

#import "movdata.h"

#define USE_MMAP

//#define LOGGING

// Determine the file size return 0 to indicate success.

static
int filesize(char *filename, uint32_t *filesize) {
  struct stat sb;
  if( 0 != stat( filename, &sb ) ) {
    return 1;
  }
  *filesize = (uint32_t) sb.st_size;
  return 0;
}

static
inline
int num_words(uint32_t numBytes)
{
	int numBytesOverWordBoundry = numBytes % 4;
	int numWords = numBytes / 4;
	if (numBytesOverWordBoundry > 0)
		numWords++;
	return numWords;
}

// AVQTAnimationFrameDecoder class

@implementation AVQTAnimationFrameDecoder

@synthesize mappedData = m_mappedData;
@synthesize currentFrameBuffer = m_currentFrameBuffer;
@synthesize cgFrameBuffers = m_cgFrameBuffers;

+ (AVQTAnimationFrameDecoder*) aVQTAnimationFrameDecoder
{
  return [[[AVQTAnimationFrameDecoder alloc] init] autorelease];
}

- (id) init
{
	self = [super init];
	if (self == nil)
		return nil;
  
	self->frameIndex = -1;
  
	return self;
}

- (void) _allocateInputBuffer:(NSUInteger)numWords
{
  assert(self->inputBuffer == NULL);
	void *buf = malloc(numWords * sizeof(int));
	assert(buf);
  
	self->inputBuffer = buf;
	self->numWordsInputBuffer = numWords;
  
	return;
}

- (void) _freeInputBuffer
{
  if (self->inputBuffer) {
    free(self->inputBuffer);
    self->inputBuffer = NULL;
  }
}

- (void) dealloc
{
	if (movFile != NULL) {
		[self close];
  }
  if (movData != NULL) {
    movdata_free(movData);
    free(movData);
  }
  [self _freeInputBuffer];
  self.mappedData = nil;
  self.currentFrameBuffer = nil;
  
  /*
   for (CGFrameBuffer *aBuffer in self.cgFrameBuffers) {
   int count = [aBuffer retainCount];
   count = count;
   
   if (aBuffer.isLockedByDataProvider) {
   NSString *msg = [NSString stringWithFormat:@"%@, count %d",
   @"CGFrameBuffer is still locked by UIKit", count];
   NSLog(msg);
   
   if ([aBuffer isLockedByImageRef:imgRef1]) {
   NSLog(@"locked by imgRef1");
   } else if ([aBuffer isLockedByImageRef:imgRef2]) {
   NSLog(@"locked by imgRef2");
   } else if ([aBuffer isLockedByImageRef:imgRef3]) {
   NSLog(@"locked by imgRef3");
   } else {
   NSLog(@"locked by unknown image ref");				
   }
   }
   }
   */
  self.cgFrameBuffers = nil;
  
	[super dealloc];
}

- (void) _allocFrameBuffers
{
	// create buffers used for loading image data
  
  if (self.cgFrameBuffers != nil) {
    // Already allocated the frame buffers
    return;
  }
  
	int renderWidth = [self width];
	int renderHeight = [self height];
  
  NSAssert(renderWidth > 0 && renderHeight > 0, @"renderWidth or renderHeight is zero");
  
  int bitsPerPixel = movData->bitDepth;
  
	CGFrameBuffer *cgFrameBuffer1 = [CGFrameBuffer cGFrameBufferWithBppDimensions:bitsPerPixel width:renderWidth height:renderHeight];
  CGFrameBuffer *cgFrameBuffer2 = [CGFrameBuffer cGFrameBufferWithBppDimensions:bitsPerPixel width:renderWidth height:renderHeight];
  CGFrameBuffer *cgFrameBuffer3 = [CGFrameBuffer cGFrameBufferWithBppDimensions:bitsPerPixel width:renderWidth height:renderHeight];
  
	self.cgFrameBuffers = [NSArray arrayWithObjects:cgFrameBuffer1, cgFrameBuffer2, cgFrameBuffer3, nil];
  
  // Double check size assumptions
  
  if (bitsPerPixel == 16) {
    NSAssert(cgFrameBuffer1.bytesPerPixel == 2, @"invalid bytesPerPixel");
  } else if (bitsPerPixel == 24 || bitsPerPixel == 32) {
    NSAssert(cgFrameBuffer1.bytesPerPixel == 4, @"invalid bytesPerPixel");
  } else {
    NSAssert(FALSE, @"invalid bitsPerPixel");
  }
}

- (CGFrameBuffer*) _getNextFramebuffer
{
	CGFrameBuffer *cgFrameBuffer = nil;
	for (CGFrameBuffer *aBuffer in self.cgFrameBuffers) {
    if (aBuffer == self.currentFrameBuffer) {
      continue;
    }
		if (!aBuffer.isLockedByDataProvider) {
			cgFrameBuffer = aBuffer;
			break;
		}
	}
	if (cgFrameBuffer == nil) {
		NSAssert(FALSE, @"no cgFrameBuffer is available");
	}
  return cgFrameBuffer;
}

- (BOOL) _readHeader:(uint32_t)filesize path:(NSString*)path
{
	// opening the file reads the header data
  
  self->movData = malloc(sizeof(MovData));
  assert(self->movData);
  movdata_init(self->movData);
  
  int result;
  
  result = process_atoms(self->movFile, self->movData, filesize);
  
  if (result != 0) {
    fprintf(stderr, "%s\n", self->movData->errMsg);
    return FALSE;
  }
  
  result = process_sample_tables(movFile, self->movData);
  
  if (result != 0) {
    fprintf(stderr, "%s\n", self->movData->errMsg);
    return FALSE;
  }
  
  assert(self->movData->maxSampleSize > 0);
  
  assert(self->movData->bitDepth == 16 || self->movData->bitDepth == 24 || self->movData->bitDepth == 32);
  
#ifdef USE_MMAP
  [self close];
  self->m_isOpen = TRUE;
  self.mappedData = [NSData dataWithContentsOfMappedFile:path];
  NSAssert(self.mappedData, @"could not map movie file");
#else
	// Figure out good size for input buffer.
  
  int maxNumWords = num_words(movData->maxSampleSize);
  
	[self _allocateInputBuffer:maxNumWords];
  
# ifdef LOG_MISSED_BUFFER_USAGE
	NSLog(@"allocated input buffer of size %d bytes", maxNumWords*sizeof(int));
# endif // LOG_MISSED_BUFFER_USAGE	  
  
#endif // USE_MMAP
  
	return TRUE;
}

- (BOOL) openForReading:(NSString*)flatMoviePath
{
	if (self->m_isOpen)
		return FALSE;
  
	char *flatFilePath = (char*) [flatMoviePath UTF8String];
	self->movFile = fopen(flatFilePath, "rb");
  
	if (movFile == NULL) {
		return FALSE;
	}
  
  uint32_t fsize;
  int status = filesize(flatFilePath, &fsize);
	if (status != 0) {
		return FALSE;
	}
  
	if ([self _readHeader:fsize path:flatMoviePath] == FALSE) {
		[self close];
		return FALSE;
	}

  // Frame buffers need to be allocated after the movie headers have been read, so we know the width and height
  
	[self _allocFrameBuffers];  
  
	self->m_isOpen = TRUE;
	return TRUE;
}

- (void) close
{
	if (self->movFile != NULL) {
		fclose(self->movFile);
		self->movFile = NULL;
	}
  
  self.mappedData = nil;
  [self _freeInputBuffer];
  
	frameIndex = -1;
  self.currentFrameBuffer = nil;
  
  self->m_isOpen = FALSE;
}

- (void) rewind
{
	if (!self->m_isOpen) {
		return;
  }
  
	frameIndex = -1;
  self.currentFrameBuffer = nil;
}

- (UIImage*) advanceToFrame:(NSUInteger)newFrameIndex
{
  // Get from queue of frame buffers!
  
  CGFrameBuffer *nextFrameBuffer = [self _getNextFramebuffer];

  // Double check that the current frame is not the exact same object as the one we pass as
  // the next frame buffer. This should not happen, and we can't copy the buffer into itself.
  
  NSAssert(nextFrameBuffer != self.currentFrameBuffer, @"current and next frame buffers can't be the same object");

  // Advance to same frame is a no-op

	if ((frameIndex != -1) && (newFrameIndex == frameIndex)) {
    return nil;
	} else if ((frameIndex != -1) && (newFrameIndex < frameIndex)) {
    	// movie frame index can only go forward via advanceToFrame
		NSString *msg = [NSString stringWithFormat:@"%@: %d -> %d",
                     @"can't advance to frame before current frameIndex",
                     frameIndex,
                     newFrameIndex];
		NSAssert(FALSE, msg);
  }
  
	// Get the number of frames directly from the header
	// instead of invoking method to query self.numFrames.
  
  int numFrames = self->movData->numFrames;
  
	if (newFrameIndex >= numFrames) {
		NSString *msg = [NSString stringWithFormat:@"%@: %d",
                     @"can't advance past last frame",
                     newFrameIndex];
		NSAssert(FALSE, msg);
	}
  
	BOOL changeFrameData = FALSE;
	const int newFrameIndexSigned = (int) newFrameIndex;
  MovSample **frames = movData->frames;
  
#ifdef USE_MMAP
  char *mappedPtr = (char*) [self.mappedData bytes];
  NSAssert(mappedPtr, @"mappedPtr");
#endif // USE_MMAP
  
  // Check for the case where multiple frames need to be processed,
  // if one of the frames between the current frame and the target
  // frame is a keyframe, then save time by skipping directly to
  // that keyframe (avoids memcpy when not needed) and then
  // applying deltas from the keyframe to the target frame.
  
  if ((newFrameIndexSigned > 0) && ((newFrameIndexSigned - frameIndex) > 1)) {
    int lastKeyframeIndex = -1;
    
    for ( int i = frameIndex ; i < newFrameIndexSigned; i++) {
      int actualFrameIndex = i + 1;
      MovSample *frame = frames[actualFrameIndex];
      
      if ((actualFrameIndex > 0) && (frame == frames[actualFrameIndex-1])) {
        // This frame is a no-op, since it duplicates data from the previous frame.
      } else {
        if (movsample_iskeyframe(frame)) {
          lastKeyframeIndex = i;
        }
      }
    }
    // Don't set frameIndex for the first frame (frameIndex == -1)
    if (lastKeyframeIndex > -1) {
      frameIndex = lastKeyframeIndex;
    }
  }
  
  // loop from current frame to target frame, applying deltas as we go.
  
	for ( ; frameIndex < newFrameIndexSigned; frameIndex++) {
    int actualFrameIndex = frameIndex + 1;
    MovSample *frame = frames[actualFrameIndex];
    
    if ((actualFrameIndex > 0) && (frame == frames[actualFrameIndex-1])) {
      // This frame is a no-op, since it duplicates data from the previous frame.
      //      fprintf(stdout, "Frame %d NOP\n", actualFrameIndex);
    } else {
      //      fprintf(stdout, "Frame %d [Size %d Offset %d Keyframe %d]\n", actualFrameIndex, frame->offset, movsample_length(frame), movsample_iskeyframe(frame));
			changeFrameData = TRUE;
      
      if (self.currentFrameBuffer != nextFrameBuffer) {
        // Copy the previous frame buffer unless there was not one, or current is a keyframe
        
        if (self.currentFrameBuffer != nil && !movsample_iskeyframe(frame)) {
          [nextFrameBuffer copyPixels:self.currentFrameBuffer];
        }
        self.currentFrameBuffer = nextFrameBuffer;
      }
      
#ifdef USE_MMAP
      process_rle_sample(mappedPtr, self->movData, frame, nextFrameBuffer.pixels);
#else
      read_process_rle_sample(self->movFile, self->movData, frame, nextFrameBuffer.pixels, inputBuffer, numWordsInputBuffer * sizeof(int));
#endif // USE_MMAP
    }
	}
  
  if (!changeFrameData) {
    return nil;
  } else {
    // Return a CGImage wrapped in a UIImage
    
    CGFrameBuffer *cgFrameBuffer = self.currentFrameBuffer;
    CGImageRef imgRef = [cgFrameBuffer createCGImageRef];
    NSAssert(imgRef, @"CGImageRef returned by createCGImageRef is NULL");
    
    UIImage *uiImage = [UIImage imageWithCGImage:imgRef];
    CGImageRelease(imgRef);

    NSAssert(cgFrameBuffer.isLockedByDataProvider, @"image buffer should be locked by frame UIImage");
    
    NSAssert(uiImage, @"uiImage is nil");
    return uiImage;    
  }
}

// Return the current frame buffer, this is the buffer that was most recently written to via
// a call to advanceToFrame. Returns nil on init or after a rewind operation.

- (CGFrameBuffer*) currentFrameBuffer
{
  return self->m_currentFrameBuffer;
}

// Properties

- (NSUInteger) width
{
  return self->movData->width;
}

- (NSUInteger) height
{
  return self->movData->height;
}

- (BOOL) isOpen
{
  return self->m_isOpen;
}

- (NSUInteger) numFrames
{
  return self->movData->numFrames;
}

- (int) frameIndex
{
  return self->frameIndex;
}

- (NSTimeInterval) frameDuration
{
  return 1.0 / movData->fps;
}

- (BOOL) hasAlphaChannel
{
  NSAssert(movData, @"movData is NULL");
  if (movData->bitDepth == 16 || movData->bitDepth == 24) {
    return FALSE;
  } else if (movData->bitDepth == 32) {
    return TRUE;
  } else {
    assert(0);
  }
}

@end
