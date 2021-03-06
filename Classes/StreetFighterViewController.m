//
//  StreetFighterViewController.m
//  StreetFighter
//
//  Created by Moses DeJong on 1/22/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "StreetFighterViewController.h"

#import "AutoPropertyRelease.h"

#import "AutoTimer.h"

#import "AVAnimatorView.h"

#import "AVAnimatorMedia.h"

#import "AVMvidFrameDecoder.h"

#import "AVAppResourceLoader.h"

#import "AV7zAppResourceLoader.h"

#import "AVFileUtil.h"

#import <AVFoundation/AVAudioPlayer.h>

#define ENABLE_SOUND

static int stanceCount = 0;

#import "StreetFighterAppDelegate.h"

@implementation StreetFighterViewController

@synthesize renderView = m_renderView;
@synthesize stanceMedia = m_stanceMedia;
@synthesize punchMedia = m_punchMedia;
@synthesize kickMedia = m_kickMedia;
@synthesize fireballMedia = m_fireballMedia;
@synthesize bgAudioPlayer = m_bgAudioPlayer;
@synthesize fightPlayer = m_fightPlayer;
@synthesize readyTimer = m_readyTimer;

+ (StreetFighterViewController*) streetFighterViewController
{
  StreetFighterViewController *obj = [[StreetFighterViewController alloc] initWithNibName:@"StreetFighterViewController" bundle:nil];
    
#if __has_feature(objc_arc)
  return obj;
#else
  return [obj autorelease];
#endif // objc_arc
}

- (void)makeIndexedAnimationMedia:(int)index
{
  // The animator view is placed inside the containerView so that the
  // bottom is aligned.
  
  float ratio = 137.0 / 106.0; // ryu stance height at screen size of 320
  //  float ratio = 1.0;
  
  NSString *movieResourceFilename;
  int movieWidth;
  int movieHeight;
  // Distance from left edge of movie to center of Ryu's belt
  int movieCenterX;
  
  if (index == 0) {
    // stance
    movieWidth = 50;
    movieHeight = 106;
    movieCenterX = 23;
    movieResourceFilename = @"RyuStance.mvid";
  } else if (index == 1) {
    // punch
    movieWidth = 126;
    movieHeight = 115;
    movieCenterX = 25;
    movieResourceFilename = @"RyuStrongPunch.mvid";    
  } else if (index == 2) {
    // kick
    movieWidth = 116;
    movieHeight = 115;
    movieCenterX = 50;
    movieResourceFilename = @"RyuHighKick.mvid";
  } else if (index == 3) {
    // Fireball
    movieWidth = 194;
    movieHeight = 119;
    movieCenterX = 28;
    movieResourceFilename = @"RyuFireball.mvid";    
  } else {
    assert(0);
  }
  
  int viewWidth = round(movieWidth * ratio);
  int viewHeight = round(movieHeight * ratio);
  int viewCenterX = round(movieCenterX * ratio);
  
  int viewLeftEdgeX = 120;
  int viewMaxY = 290;
  
  int viewX = viewLeftEdgeX - viewCenterX;
  int viewY = viewMaxY - viewHeight;
  
  CGRect frame = CGRectMake(viewX, viewY, viewWidth, viewHeight);
  
  AVAnimatorMedia *media = [AVAnimatorMedia aVAnimatorMedia];
  
  // Load animation videos from iOS optimized .mvid files in RyuMvids.7z archive.
  // Note that if the .mvid file has already been decoded to disk, then this
  // loader will use the already decompressed file sitting on disk.
  
  AV7zAppResourceLoader *resLoader = [AV7zAppResourceLoader aV7zAppResourceLoader];
  resLoader.archiveFilename = @"RyuMvids.7z";
  resLoader.movieFilename = movieResourceFilename;
  resLoader.outPath = [AVFileUtil getTmpDirPath:movieResourceFilename];

  // Audio tracks are loaded directly from attached resource .wav files
  
  if (index == 0) {
    self->stanceFrame = frame;
    self.stanceMedia = media;
  } else if (index == 1) {
    self->punchFrame = frame;
    self.punchMedia = media;
#ifdef ENABLE_SOUND
    resLoader.audioFilename = @"Punch-fierce.wav";
#endif
  } else if (index == 2) {
    self->kickFrame = frame;
    self.kickMedia = media;
#ifdef ENABLE_SOUND
    resLoader.audioFilename = @"Kick.wav";
#endif
  } else {
    self->fireballFrame = frame;
    self.fireballMedia = media;
#ifdef ENABLE_SOUND
    resLoader.audioFilename = @"Hadoken.wav";
#endif
  }  
  
	media.resourceLoader = resLoader;

  // Create decoder that will generate frames from Quicktime Animation encoded data
  
  AVMvidFrameDecoder *frameDecoder = [AVMvidFrameDecoder aVMvidFrameDecoder];
	media.frameDecoder = frameDecoder;
  
  //	media.animatorFrameDuration = 1.0;
  media.animatorFrameDuration = AVAnimator10FPS;
  
  [media prepareToAnimate];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  // Create Media object for each of the audio/video clips. These media objects are not
  // connected to a renderer initially. A media object does not allocate all resources
  // until connected to a renderer, so it is perfectly fine to have many media objects
  // allocated, only the one connected to the renderer will allocate frame buffers and
  // shared memory.
  
  [self makeIndexedAnimationMedia:0];

  [self makeIndexedAnimationMedia:1];
  
  [self makeIndexedAnimationMedia:2];

  [self makeIndexedAnimationMedia:3];

  self.renderView = [AVAnimatorView aVAnimatorViewWithFrame:stanceFrame];
  [self.view addSubview:self.renderView];
  
  NSArray *array = [NSArray arrayWithObjects:self.stanceMedia, self.punchMedia, self.kickMedia, self.fireballMedia, nil];
  
  for (AVAnimatorMedia *media in array) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(animatorDoneNotification:) 
                                                 name:AVAnimatorDoneNotification
                                               object:media];
  }
  
  // Load background audio clip that plays all the time in a loop
  
#ifdef ENABLE_SOUND
  if (1)
#else
  if (0)
#endif
  {

  NSString *resFilename = @"sf2_blanka_theme_mono_qlow_22k.caf";
	NSString* resPath = [[NSBundle mainBundle] pathForResource:resFilename ofType:nil];
  NSAssert(resPath, @"resPath is nil");
  NSURL *url = [NSURL fileURLWithPath:resPath];

  AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];

#if __has_feature(objc_arc)
  self.bgAudioPlayer = player;
#else
  self.bgAudioPlayer = [player autorelease];
#endif // objc_arc
      
  [self.bgAudioPlayer prepareToPlay];
  self.bgAudioPlayer.numberOfLoops = 1000;
  [self.bgAudioPlayer play];
    
  }
  
  // Play "fight" clip once

#ifdef ENABLE_SOUND
  if (1)
#else
  if (0)
#endif      
  {

  NSString *resFilename = @"Fight.wav";
	NSString* resPath = [[NSBundle mainBundle] pathForResource:resFilename ofType:nil];
  NSAssert(resPath, @"resPath is nil");
  NSURL *url = [NSURL fileURLWithPath:resPath];
      
  AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];

#if __has_feature(objc_arc)
  self.fightPlayer = player;
#else
  self.fightPlayer = [player autorelease];
#endif // objc_arc

  [self.fightPlayer prepareToPlay];
  
  }
  
  // Setup a callback that will do the initial animation
  // once the view has been loaded. Media can't be attached
  // to a view while it is under construction, so we
  // want to wait until this view is finished loading.
  
  self.readyTimer = [AutoTimer autoTimerWithTimeInterval:0.1
                                                  target:self
                                                selector:@selector(readyCallback:)
                                                userInfo:nil
                                                 repeats:FALSE];
}

- (void) readyCallback:(NSTimer*)timer
{
#ifdef ENABLE_SOUND
  [self.fightPlayer play];
#endif
  
  [self animatorAction:0];
  
  return;
}

- (void)animatorAction:(int)action {
  // Stance, Punch, Kick, Fireball
  // Note that an action is ignored if an animation other than
  // the stance animation is currently running.

  BOOL isPunchAnimating = [self.punchMedia isAnimatorRunning];
  BOOL isKickAnimating = [self.kickMedia isAnimatorRunning];
  BOOL isFireballAnimating = [self.fireballMedia isAnimatorRunning];
  
  if (isPunchAnimating || isKickAnimating || isFireballAnimating) {
    return;
  }

  if ([self.stanceMedia isAnimatorRunning]) {
    [self.stanceMedia stopAnimator];
  }
  
  if (action == 0) {
    // Loop stance animation
    self.renderView.frame = stanceFrame;
    [self.renderView attachMedia:self.stanceMedia];
    self.stanceMedia.animatorRepeatCount = 5;    
    [self.stanceMedia startAnimator];
    
    // Setting the 0 to 1 will mean that this view controller is cleaned up
    // after some number of repeats of the stance animation. This logic is
    // usedful to check that the dealloc method of this view controller is
    // getting released and that there are no memory leaks.
    
    if (0 && stanceCount++ > 100) {
      // Done looping, stop playback and cleanup all windows
      [self.stanceMedia stopAnimator];
      [self.view removeFromSuperview];
      
      StreetFighterAppDelegate *appDelegate =
        (StreetFighterAppDelegate *) [[UIApplication sharedApplication] delegate];
      
      appDelegate.viewController = nil;
      appDelegate.window = nil;
    }
  } else if (action == 1) {
    // Run punch animation
    self.renderView.frame = punchFrame;
    [self.renderView attachMedia:self.punchMedia];
    [self.punchMedia startAnimator];
  } else if (action == 2) {
    // Run kick animation
    self.renderView.frame = kickFrame;
    [self.renderView attachMedia:self.kickMedia];
    [self.kickMedia startAnimator];
  } else if (action == 3) {
    // Run fireball animation
    self.renderView.frame = fireballFrame;
    [self.renderView attachMedia:self.fireballMedia];
    [self.fireballMedia startAnimator];
  } else {
    assert(0);
  }
  
}

- (void)animatorDoneNotification:(NSNotification*)notification {
	//NSLog( @"animatorDoneNotification" );
  [self animatorAction:0];
}

- (IBAction) punchAction:(id)sender
{
  [self animatorAction:1];
}

- (IBAction) kickAction:(id)sender
{
  [self animatorAction:2];
}

- (IBAction) fireballAction:(id)sender
{
  [self animatorAction:3];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationLandscapeRight);
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
  // Release any retained subviews of the main view.
  self.renderView = nil;
}

- (void)dealloc {
#ifdef ENABLE_SOUND
  if (1)
#else
  if (0)
#endif
  {
    [self.bgAudioPlayer stop];
    [self.fightPlayer stop];
  }
  [[NSNotificationCenter defaultCenter] removeObserver:self];

#if __has_feature(objc_arc)
#else
  [AutoPropertyRelease releaseProperties:self thisClass:StreetFighterViewController.class];
  [super dealloc];
#endif // objc_arc
}

@end
