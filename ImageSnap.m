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

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDeviceInput *captureDeviceInput;
@property (nonatomic, strong) AVCaptureStillImageOutput *captureStillImageOutput;
@property (nonatomic, assign) CVImageBufferRef currentImageBuffer;
@property (nonatomic, strong) AVCaptureConnection *videoConnection;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;

#if OS_OBJECT_HAVE_OBJC_SUPPORT == 1
@property (nonatomic, strong) dispatch_queue_t imageQueue;
#else
@property (nonatomic, assign) dispatch_queue_t imageQueue;
#endif

@end

@implementation ImageSnap

#pragma mark - Object Lifecycle

- (instancetype)init {
    self = [super init];

    if (self) {
        _dateFormatter = [NSDateFormatter new];
        _dateFormatter.dateFormat = @"yyyy-MM-dd_HH-mm-ss.SSS";

        _imageQueue = dispatch_queue_create("Image Queue", NULL);
    }

    return self;
}

- (void)dealloc {
    [self.captureSession stopRunning];
    CVBufferRelease(self.currentImageBuffer);
}

#pragma mark - Public Interface

/**
 * Returns all attached AVCaptureDevice objects that have video.
 * This includes video-only devices (AVMediaTypeVideo) and
 * audio/video devices (AVMediaTypeMuxed).
 *
 * @return array of video devices
 */
+ (NSArray *)videoDevices {
    NSMutableArray *results = [NSMutableArray new];

    [results addObjectsFromArray:[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]];
    [results addObjectsFromArray:[AVCaptureDevice devicesWithMediaType:AVMediaTypeMuxed]];

    return results;
}

// Returns the default video device or nil if none found.
+ (AVCaptureDevice *)defaultVideoDevice {

    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    if (device == nil) {
        device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeMuxed];
    }

    return device;
}

// Returns the named capture device or nil if not found.
+ (AVCaptureDevice *)deviceNamed:(NSString *)name {
    AVCaptureDevice *result;

    NSArray *devices = [ImageSnap videoDevices];
    for (AVCaptureDevice *device in devices) {
        if ([name isEqualToString:device.localizedName]) {
            result = device;
        }
    }

    return result;
}

- (void)saveSingleSnapshotFrom:(AVCaptureDevice *)device
                        toFile:(NSString *)path
                    withWarmup:(NSNumber *)warmup
                 withTimelapse:(NSNumber *)timelapse {

    double interval = timelapse == nil ? -1 : timelapse.doubleValue;

    verbose("Starting device...");
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

        for (unsigned long seq = 0; ; seq++) {

            // capture and write
            [self takeSnapshotWithFilename:[self fileNameWithSequenceNumber:seq]];                // Capture a frame

            // sleep
            [[NSRunLoop currentRunLoop] runUntilDate:[[NSDate date] dateByAddingTimeInterval:interval]];
        }

    } else {
        [self takeSnapshotWithFilename:path];                // Capture a frame
    }

    [self stopSession];
}

- (void)setUpSessionWithDevice:(AVCaptureDevice *)device {

    NSError *error;

    // Create the capture session
    self.captureSession = [AVCaptureSession new];
    if ([self.captureSession canSetSessionPreset:AVCaptureSessionPresetPhoto]) {
        self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto;
    }

    // Create input object from the device
    self.captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!error && [self.captureSession canAddInput:self.captureDeviceInput]) {
        [self.captureSession addInput:self.captureDeviceInput];
    }

    self.captureStillImageOutput = [AVCaptureStillImageOutput new];
    self.captureStillImageOutput.outputSettings = @{ AVVideoCodecKey : AVVideoCodecJPEG};

    if ([self.captureSession canAddOutput:self.captureStillImageOutput]) {
        [self.captureSession addOutput:self.captureStillImageOutput];
    }

    for (AVCaptureConnection *connection in self.captureStillImageOutput.connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([port.mediaType isEqual:AVMediaTypeVideo] ) {
                self.videoConnection = connection;
                break;
            }
        }
        if (self.videoConnection) { break; }
    }

    if ([self.captureSession canAddOutput:self.captureStillImageOutput]) {
        [self.captureSession addOutput:self.captureStillImageOutput];
    }
}

- (void)getReadyToTakePicture {
    [self.captureSession startRunning];
}

#pragma mark - Internal Methods

/**
 * Returns current snapshot or nil if there is a problem
 * or session is not started.
 */
- (void)takeSnapshotWithFilename:(NSString *)filename {
    __weak __typeof__(filename) weakFilename = filename;

    [self.captureStillImageOutput captureStillImageAsynchronouslyFromConnection:self.videoConnection
                                                              completionHandler:
     ^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {

         NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];

         dispatch_async(self.imageQueue, ^{
             [imageData writeToFile:weakFilename atomically:YES];
         });
     }];
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
            self.captureStillImageOutput = nil;
        }
    }
}

- (NSString *)fileNameWithSequenceNumber:(unsigned long)sequenceNumber {

    NSDate *now = [NSDate date];
    NSString *nowstr = [self.dateFormatter stringFromDate:now];

    return [NSString stringWithFormat:@"snapshot-%05lu-%s.jpg", sequenceNumber, nowstr.UTF8String];
}

@end
