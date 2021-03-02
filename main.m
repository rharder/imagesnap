#import <Foundation/Foundation.h>

#import "ImageSnap.h"

int processArguments(int argc, const char * argv[]);
void printUsage(int argc, const char * argv[]);
unsigned long listDevices(void);
NSString *generateFilename(void);
AVCaptureDevice *getDefaultDevice(void);

int main(int argc, const char * argv[]) {
    NSApplicationLoad();    // May be necessary for 10.5 not to crash.

    @autoreleasepool {
        [NSApplication sharedApplication];

        int result = processArguments(argc, argv);

        return result;
    }
}

/**
 * Process command line arguments and execute program.
 */
int processArguments(int argc, const char * argv[]) {

    NSString *filename;
    AVCaptureDevice *device;
    NSNumber *warmup;
    NSNumber *timelapse;

    for (int i = 1; i < argc; ++i) {

        // Handle command line switches
        if (argv[i][0] == '-') {

            // Dash only? Means write image to stdout
            // This is no longer supported.
            if (argv[i][1] == 0) {
                filename = @"-";
                g_quiet = YES;
            } else {

                // Which switch was given
                switch (argv[i][1]) {

                        // Help
                    case '?':
                    case 'h':
                        printUsage(argc, argv);
                        return 0;
                        break;


                        // Verbose
                    case 'v':
                        g_verbose = YES;
                        break;

                    case 'q':
                        g_quiet = YES;
                        break;


                        // List devices
                    case 'l':
                        listDevices();
                        return 0;
                        break;

                        // Specify device
                    case 'd':
                        if (i+1 < argc) {
                            device = [ImageSnap deviceNamed:@(argv[i+1])];
                            if (device == nil) {
                                error("Device \"%s\" not found.\n", argv[i+1]);
                                return 11;
                            }
                            ++i; // Account for "follow on" argument
                        } else {
                            error("Not enough arguments given with 'd' flag.\n");
                            return (int)'d';
                        }
                        break;

                        // Specify a warmup period before picture snaps
                    case 'w':
                        if (i+1 < argc) {
                            warmup = @(@(argv[i+1]).floatValue);
                            ++i; // Account for "follow on" argument
                        } else {
                            error("Not enough arguments given with 'w' flag.\n");
                            return (int)'w';
                        }
                        break;

                        // Timelapse
                    case 't':
                        if (i+1 < argc) {
                            timelapse = @(@(argv[i+1]).doubleValue);
                            ++i; // Account for "follow on" argument
                        } else {
                            error("Not enough arguments given with 't' flag.\n");
                            return (int)'t';
                        }
                        break;
                }
            }
        } else {
            // assume it's a filename
            filename = @(argv[i]);
        }

    }

    // Make sure we have a filename
    if (filename == nil) {
        filename = generateFilename();
        verbose("No filename specified. Using %s\n", [filename UTF8String]);
    }

    if (filename == nil) {
        error("No suitable filename could be determined.\n");
        return 1;
    }

    // Make sure we have a device
    if (device == nil) {
        device = getDefaultDevice();
        verbose("No device specified. Using %s\n", [device.description UTF8String]);
    }

    if (device == nil) {
        error("No video devices found.\n");
        return 2;
    } else {
        console("Capturing image from device \"%s\"...", [device.description UTF8String]);
    }

    // Image capture
    ImageSnap *imageSnap = [ImageSnap new];
    [imageSnap setUpSessionWithDevice:device];
    [imageSnap getReadyToTakePicture];
    [imageSnap saveSingleSnapshotFrom:device toFile:filename withWarmup:warmup withTimelapse:timelapse];

    return 0;
}

void printUsage(int argc, const char * argv[]) {
    printf("USAGE: %s [options] [filename]\n", argv[0]);
    printf("Version: %s\n", VERSION.UTF8String);
    printf("Captures an image from a video device and saves it in a file.\n");
    printf("If no device is specified, the system default will be used.\n");
    printf("If no filename is specfied, snapshot.jpg will be used.\n");
    printf("JPEG is the only supported output type.\n");
    printf("  -h          This help message\n");
    printf("  -v          Verbose mode\n");
    printf("  -l          List available video devices\n");
    printf("  -t x.xx     Take a picture every x.xx seconds\n");
    printf("  -q          Quiet mode. Do not output any text\n");
    printf("  -w x.xx     Warmup. Delay snapshot x.xx seconds after turning on camera\n");
    printf("  -d device   Use named video device\n");
}

/**
 * Prints a list of video capture devices to standard out.
 */
unsigned long listDevices() {
    NSArray *devices = [ImageSnap videoDevices];

    printf(devices.count > 0 ? "Video Devices:\n" : "No video devices found.\n");

    for (AVCaptureDevice *device in devices) {
        printf("=> %s\n", device.localizedName.UTF8String);
    }
    return devices.count;
}

/**
 * Generates a filename for saving the image, presumably
 * because the user didn't specify a filename.
 */
NSString *generateFilename() {
    return @"snapshot.jpg";
}

/**
 * Gets a default video device, or nil if none is found.
 * For now, simply queries ImageSnap.
 */
AVCaptureDevice *getDefaultDevice() {
    return [ImageSnap defaultVideoDevice];
}
