//
//  ImageSnap.m
//  ImageSnap
//
//  Created by Robert Harder on 9/10/09.
//

#import "ImageSnap.h"

static BOOL g_verbose = NO;
static BOOL g_quiet = NO;

NSString *const VERSION = @"0.2.5";

@interface ImageSnap()

- (void)captureOutput:(QTCaptureOutput *)captureOutput
  didOutputVideoFrame:(CVImageBufferRef)videoFrame
     withSampleBuffer:(QTSampleBuffer *)sampleBuffer
       fromConnection:(QTCaptureConnection *)connection;

@property (nonatomic, strong) QTCaptureSession *captureSession;
@property (nonatomic, strong) QTCaptureDeviceInput *captureDeviceInput;
@property (nonatomic, strong) QTCaptureDecompressedVideoOutput *captureDecompressedVideoOutput;
@property (nonatomic, assign) CVImageBufferRef currentImageBuffer;

@end

@implementation ImageSnap

- (void)dealloc {
    CVBufferRelease(self.currentImageBuffer);
}

// Returns an array of video devices attached to this computer.
+ (NSArray *)videoDevices {
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:3];
    [results addObjectsFromArray:[QTCaptureDevice inputDevicesWithMediaType:QTMediaTypeVideo]];
    [results addObjectsFromArray:[QTCaptureDevice inputDevicesWithMediaType:QTMediaTypeMuxed]];

    return results;
}

// Returns the default video device or nil if none found.
+ (QTCaptureDevice *)defaultVideoDevice {

    QTCaptureDevice *device = [QTCaptureDevice defaultInputDeviceWithMediaType:QTMediaTypeVideo];

    if (device == nil) {
        device = [QTCaptureDevice defaultInputDeviceWithMediaType:QTMediaTypeMuxed];
    }

    return device;
}

// Returns the named capture device or nil if not found.
+ (QTCaptureDevice *)deviceNamed:(NSString *)name {
    QTCaptureDevice *result;

    NSArray *devices = [ImageSnap videoDevices];
    for (QTCaptureDevice *device in devices) {
        if ([name isEqualToString:device.description]) {
            result = device;
        }
    }

    return result;
}

// Saves an image to a file or standard out if path is nil or "-" (hyphen).
+ (BOOL)saveImage:(NSImage *)image toPath:(NSString *)path {

    NSString *ext = path.pathExtension;
    NSData *photoData = [ImageSnap dataFrom:image asType:ext];

    // If path is a dash, that means write to standard out
    if (path == nil || [@"-" isEqualToString:path]) {
        NSUInteger length = photoData.length;
        NSUInteger i;
        char *start = (char *)photoData.bytes;
        for (i = 0; i < length; ++i) {
            putc(start[i], stdout );
        }

        return YES;
    } else {

        return [photoData writeToFile:path atomically:NO];
    }

    return NO;
}

/**
 * Converts an NSImage into NSData.
 */
+ (NSData *)dataFrom:(NSImage *)image asType:(NSString *)format {

    NSData *tiffData = image.TIFFRepresentation;

    NSBitmapImageFileType imageType = NSJPEGFileType;
    NSDictionary *imageProps;

    if ([@"tif" rangeOfString:format options:NSCaseInsensitiveSearch].location != NSNotFound ||
       [@"tiff" rangeOfString:format options:NSCaseInsensitiveSearch].location != NSNotFound) {
    // TIFF. Special case. Can save immediately.
        return tiffData;
    } else if ([@"jpg"  rangeOfString:format options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [@"jpeg" rangeOfString:format options:NSCaseInsensitiveSearch].location != NSNotFound) {
    // JPEG
        imageType = NSJPEGFileType;
        imageProps = @{NSImageCompressionFactor: @0.9f};
    } else if ([@"png" rangeOfString:format options:NSCaseInsensitiveSearch].location != NSNotFound) {
    // PNG
        imageType = NSPNGFileType;
    } else if ([@"bmp" rangeOfString:format options:NSCaseInsensitiveSearch].location != NSNotFound) {
    // BMP
        imageType = NSBMPFileType;
    } else if ([@"gif" rangeOfString:format options:NSCaseInsensitiveSearch].location != NSNotFound) {
    // GIF
        imageType = NSGIFFileType;
    }

    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:tiffData];
    NSData *photoData = [imageRep representationUsingType:imageType properties:imageProps];

    return photoData;
}

/**
 * Primary one-stop-shopping message for capturing an image.
 * Activates the video source, saves a frame, stops the source,
 * and saves the file.
 */
+ (BOOL)saveSingleSnapshotFrom:(QTCaptureDevice *)device toFile:(NSString *)path {
    return [self saveSingleSnapshotFrom:device toFile:path withWarmup:nil];
}

+ (BOOL)saveSingleSnapshotFrom:(QTCaptureDevice *)device toFile:(NSString *)path withWarmup:(NSNumber *)warmup {
    return [self saveSingleSnapshotFrom:device toFile:path withWarmup:warmup withTimelapse:nil];
}

+ (BOOL)saveSingleSnapshotFrom:(QTCaptureDevice *)device
                        toFile:(NSString *)path
                    withWarmup:(NSNumber *)warmup
                 withTimelapse:(NSNumber *)timelapse {
    ImageSnap *snap;
    NSImage *image;
    double interval = timelapse == nil ? -1 : timelapse.doubleValue;

    snap = [[ImageSnap alloc] init];            // Instance of this ImageSnap class
    verbose("Starting device...");
    if ([snap startSession:device]) {           // Try starting session
        verbose("Device started.\n");

        if (warmup == nil) {
            // Skip warmup
            verbose("Skipping warmup period.\n");
        } else {
            double delay = warmup.doubleValue;
            verbose("Delaying %.2lf seconds for warmup...", delay);
            NSDate *now = [[NSDate alloc] init];
            [[NSRunLoop currentRunLoop] runUntilDate:[now dateByAddingTimeInterval:warmup.doubleValue]];
            verbose("Warmup complete.\n");
        }

        if (interval > 0) {
            verbose("Time lapse: snapping every %.2lf seconds to current directory.\n", interval);

            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            dateFormatter.dateFormat = @"yyyy-MM-dd_HH-mm-ss.SSS";

            for (unsigned long seq = 0; ; seq++) {
                NSDate *now = [[NSDate alloc] init];
                NSString *nowstr = [dateFormatter stringFromDate:now];

                verbose(" - Snapshot %5lu", seq);
                verbose(" (%s)\n", [nowstr UTF8String]);

                NSString *filename = [NSString stringWithFormat:@"snapshot-%05lu-%s.jpg", seq, nowstr.UTF8String];

                // capture and write
                image = [snap snapshot];                // Capture a frame
                if (image != nil)  {
                    [ImageSnap saveImage:image toPath:filename];
                    console("%s\n", [filename UTF8String]);
                } else {
                    error("Image capture failed.\n" );
                }

                // sleep
                [[NSRunLoop currentRunLoop] runUntilDate:[now dateByAddingTimeInterval:interval]];
            }

        } else {
            image = [snap snapshot];                // Capture a frame
        }

        [snap stopSession];
    }

    if (interval > 0) {
        return YES;
    } else {
        return image == nil ? NO : [ImageSnap saveImage:image toPath:path];
    }
}

/**
 * Returns current snapshot or nil if there is a problem
 * or session is not started.
 */
- (NSImage *)snapshot {
    verbose("Taking snapshot...\n");

    CVImageBufferRef frame = nil;               // Hold frame we find
    while (frame == nil) {                      // While waiting for a frame

        @synchronized(self) {                    // Lock since capture is on another thread
            frame = self.currentImageBuffer;        // Hold current frame
            CVBufferRetain(frame);              // Retain it (OK if nil)
        }

        if (frame == nil) {                     // Still no frame? Wait a little while.
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }

    }

    // Convert frame to an NSImage
    NSCIImageRep *imageRep = [NSCIImageRep imageRepWithCIImage:[CIImage imageWithCVImageBuffer:frame]];
    NSImage *image = [[NSImage alloc] initWithSize:imageRep.size];
    [image addRepresentation:imageRep];
    verbose("Snapshot taken.\n" );

    return image;
}

/**
 * Blocks until session is stopped.
 */
- (void)stopSession {
    verbose("Stopping session...\n" );

    // Make sure we've stopped
    while (self.captureSession != nil) {
        verbose("\tCaptureSession != nil\n");

        verbose("\tStopping CaptureSession...");
        [self.captureSession stopRunning];
        verbose("Done.\n");

        if ([self.captureSession isRunning]) {
            verbose("[captureSession isRunning]");
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        } else {
            verbose("\tShutting down 'stopSession(..)'" );

            self.captureSession = nil;
            self.captureDeviceInput = nil;
            self.captureDecompressedVideoOutput = nil;
        }
    }
}

/**
 * Begins the capture session. Frames begin coming in.
 */
- (BOOL)startSession:(QTCaptureDevice *)device {

    verbose("Starting capture session...\n" );

    if (device == nil) {
        verbose("\tCannot start session: no device provided.\n" );
        return NO;
    }

    NSError *error;

    // If we've already started with this device, return
    if ([device isEqual:[self.captureDeviceInput device]] &&
       self.captureSession != nil &&
       [self.captureSession isRunning]) {
        return YES;
    } else if (self.captureSession != nil) {
        verbose("\tStopping previous session.\n" );
        [self stopSession];
    }

    // Create the capture session
    verbose("\tCreating QTCaptureSession..." );
    self.captureSession = [[QTCaptureSession alloc] init];
    verbose("Done.\n");
    if (![device open:&error] ) {
        error("\tCould not create capture session.\n" );
        self.captureSession = nil;
        return NO;
    }

    // Create input object from the device
    verbose("\tCreating QTCaptureDeviceInput with %s...", [[device description] UTF8String] );
    self.captureDeviceInput = [[QTCaptureDeviceInput alloc] initWithDevice:device];
    verbose("Done.\n");
    if (![self.captureSession addInput:self.captureDeviceInput error:&error]) {
        error("\tCould not convert device to input device.\n");
        self.captureSession = nil;
        self.captureDeviceInput = nil;
        return NO;
    }

    // Decompressed video output
    verbose("\tCreating QTCaptureDecompressedVideoOutput...");
    self.captureDecompressedVideoOutput = [[QTCaptureDecompressedVideoOutput alloc] init];
    [self.captureDecompressedVideoOutput setDelegate:self];
    verbose("Done.\n" );
    if (![self.captureSession addOutput:self.captureDecompressedVideoOutput error:&error]) {
        error("\tCould not create decompressed output.\n");
        self.captureSession = nil;
        self.captureDeviceInput = nil;
        self.captureDecompressedVideoOutput = nil;

        return NO;
    }

    // Clear old image?
    verbose("\tEntering synchronized block to clear memory...");
    @synchronized(self) {
        if (self.currentImageBuffer != nil ) {
            CVBufferRelease(self.currentImageBuffer);
            self.currentImageBuffer = nil;
        }   // end if: clear old image
    }   // end sync: self
    verbose("Done.\n");

    [self.captureSession startRunning];
    verbose("Session started.\n");

    return YES;
}

// This delegate method is called whenever the QTCaptureDecompressedVideoOutput receives a frame
- (void)captureOutput:(QTCaptureOutput *)captureOutput
  didOutputVideoFrame:(CVImageBufferRef)videoFrame
     withSampleBuffer:(QTSampleBuffer *)sampleBuffer
       fromConnection:(QTCaptureConnection *)connection {
    verbose("." );
    if (videoFrame == nil ) {
        verbose("'nil' Frame captured.\n" );
        return;
    }

    // Swap out old frame for new one
    CVImageBufferRef imageBufferToRelease;
    CVBufferRetain(videoFrame);

    @synchronized(self) {
        imageBufferToRelease = self.currentImageBuffer;
        self.currentImageBuffer = videoFrame;
    }   // end sync
    CVBufferRelease(imageBufferToRelease);
}

@end
