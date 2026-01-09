# ImageSnap

by: Robert Harder (original), Swift port

## Capture Images from the Command Line

ImageSnap is a command-line tool that lets you capture still images from an iSight or other video source. This is a Swift rewrite of the original Objective-C version, using modern AVFoundation APIs.

## Installation

### Building from Source

**Using Xcode:**

1. Open `ImageSnap.xcodeproj` in Xcode
2. Select **Product > Build** (⌘B)
3. The built `imagesnap` executable will be in the DerivedData folder

**Using Command Line:**

```bash
cd ImageSnap
xcodebuild -scheme imagesnap -configuration Release build
```

Or compile directly with swiftc:

```bash
swiftc -o imagesnap main.swift -framework AVFoundation -framework AppKit -framework CoreImage
```

### Installing

Copy the `imagesnap` binary to someplace on your path like `/usr/local/bin`:

```bash
cp imagesnap /usr/local/bin/
```

The first time you use the tool, you may get a popup window from macOS asking to give `imagesnap` permission to access the camera.

## Usage

To capture an image simply run the program from the command line. There is a delay of a few seconds while the camera warms up, and then...snap!

```
$ imagesnap
Capturing image from device "FaceTime HD Camera"..................snapshot.jpg
```

To specify a filename, make that your last argument:

```
$ imagesnap icu.jpg
Capturing image from device "FaceTime HD Camera"..................icu.jpg
```

If you have multiple video devices attached to your computer, use the `-l` ("el") flag to list them:

```
$ imagesnap -l
Video Devices:
=> FaceTime HD Camera
=> Logitech BRIO
=> USB 2.0 Camera
```

To select a specific video device use the `-d` flag with the full or partial name of a device:

```
$ imagesnap -d BRIO
Capturing image from device "Logitech BRIO"..................snapshot.jpg
```

You can capture a series of images in a timelapse using the `-t` option. The following command would take a picture every 60 seconds:

```
$ imagesnap -d BRIO -t 60
Capturing image from device "Logitech BRIO"..................snapshot-00001.jpg
snapshot-00002.jpg
snapshot-00003.jpg
```

Use `-n` to limit the number of timelapse captures:

```
$ imagesnap -t 10 -n 5
Capturing image from device "FaceTime HD Camera"..................snapshot-00001.jpg
snapshot-00002.jpg
snapshot-00003.jpg
snapshot-00004.jpg
snapshot-00005.jpg
```

There is a default warmup period of three seconds when you take a picture. This gives the camera time to get its sensors all set up. Your camera might have a faster or slower response time, so you can adjust the warmup period to suit your needs:

```
$ imagesnap -w 0
Capturing image from device "FaceTime HD Camera"...snapshot.jpg
```

## Command Line Options

```
USAGE: imagesnap [options] [filename]
Version: 0.3.0
Captures an image from a video device and saves it in a file.
If no device is specified, the system default will be used.
If no filename is specified, snapshot.jpg will be used.
Supported image types: JPEG, TIFF, PNG, GIF, BMP

  -h          This help message
  -v          Verbose mode
  -l          List available video devices
  -t x.xx     Take a picture every x.xx seconds
  -n x        Limit the number of timelapse pictures to x
  -q          Quiet mode. Do not output any text
  -w x.xx     Warmup. Delay snapshot x.xx seconds after turning on camera
  -d device   Use named video device
```

## Image Formats

The following image formats are supported and are determined by the filename extension:

- JPEG (.jpg, .jpeg) - default
- PNG (.png)
- TIFF (.tiff, .tif)
- GIF (.gif)
- BMP (.bmp)

## Changes

- v0.3.0 - Complete rewrite in Swift using AVFoundation. Supports macOS 13+.

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building)
- A connected camera (built-in or external)

## License

Public Domain - This software is released into the Public Domain. You can do whatever you want with it.
