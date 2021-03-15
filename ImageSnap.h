//
//  ImageSnap.h
//  ImageSnap
//
//  Created by Robert Harder on 9/10/09.
//

#import <AVFoundation/AVFoundation.h>
#import <Cocoa/Cocoa.h>
#include "ImageSnap.h"

#define error(...) (fprintf(stderr, __VA_ARGS__) && fflush(stderr))
#define console(...) (!g_quiet && printf(__VA_ARGS__) && fflush(stdout))
#define verbose(...) (g_verbose && !g_quiet && fprintf(stderr, __VA_ARGS__) && fflush(stderr))

static BOOL g_verbose = NO;
static BOOL g_quiet = NO;

FOUNDATION_EXPORT NSString *const VERSION;

@interface ImageSnap : NSObject

+ (void)setVerbose:(BOOL)verbose;
+ (void)setQuiet:(BOOL)quiet;

/**
 * Returns all attached QTCaptureDevice objects that have video.
 * This includes video-only devices (QTMediaTypeVideo) and
 * audio/video devices (QTMediaTypeMuxed).
 *
 * @return array of video devices
 */
+ (NSArray *)videoDevices;

/**
 * Returns the default QTCaptureDevice object for video
 * or nil if none is found.
 */
+ (AVCaptureDevice *)defaultVideoDevice;

/**
 * Returns the QTCaptureDevice with the given name
 * or nil if the device cannot be found.
 */
+ (AVCaptureDevice *)deviceNamed:(NSString *)name;

- (void)setUpSessionWithDevice:(AVCaptureDevice *)device;


/**
 * Primary one-stop-shopping message for capturing an image.
 * Activates the video source, saves a frame, stops the source,
 * and saves the file.
 */
- (void)saveSingleSnapshotFrom:(AVCaptureDevice *)device
                        toFile:(NSString *)path
                    withWarmup:(NSNumber *)warmup
                 withTimelapse:(NSNumber *)timelapse;

@end
