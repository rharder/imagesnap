# Image Snap

by: Robert Harder

rob@iHarder.net

## Capture Images from the Command Line

http://iharder.net/imagesnap

ImageSnap is a Public Domain command-line tool that lets you capture still
images from an iSight or other video source.

## Installation

ImageSnap is included in various package managers such as Homebrew and MacPorts.
The easiest way to install `imagesnap` is probably with one of those commands
such as `brew install imagesnap`. 

You can also simply copy the binary `imagesnap` file to someplace on 
your path like `/usr/local/bin`, or leave it in a "current directory," and 
call it with `./imagesnap` instead.  If your download has a version number
appended to it like `imagesnap-0.2.10` then I recommend you rename it
to just `imagesnap`.

The first time you use the tool, you may get a popup window from MacOS 
asking to give `imagesnap` permission to access the camera.

Enjoy!

## Usage
To capture an image simply run the program from the command line.

```
$ imagesnap
Capturing image from device "iSight"..................snapshot.jpg
````

To specify a filename, make that your last argument:

```
$ imagesnap icu.jpg
Capturing image from device "iSight"..................icu.jpg
```

If you have multiple video devices attached to your computer, use the `-l`
("el") flag to list them:

```
$ imagesnap -l
Video Devices:
=> iSight
=> DV
=> USB 2.0 Camera
```

To select a specific video device use the -d device flag with the full
or partial name of a device:

```
$ imagesnap -d Cam
Capturing image from device "USB 2.0 Camera"..................snapshot.jpg
```

## Image Formats

Only JPEG output is supported. 

## Changes

* v0.2.12 - Supports native M1.  Other tweaks for package managers.
* v0.2.11 - Some documentation updates and preparing for better integration with package managers like Homebrew and MacPorts
* v0.2.10 - Fixed bug when showing Capturing image with xxx...snapshot.jpg
* v0.2.9 - When doing timelapse, sequence numbers will pick up where the last filename left off.
* v0.2.8 - Removed timestamp from filename when doing sequence of images with `-t` option
* v0.2.7 - When specifying a device with the `-d` flag, substrings are matched if an exact match is not found.  Some cleanup in the code for modern Xcode versions.  Verified on Mojave and Big Sur
* v0.2.6 - Unknown point release four years before v0.2.7 - I don't know what it was. 
* v0.2.5 - Added option to delay the first snapshot for some time. Added a time-lapse feature (thanks, Bas Zoetekouw).
* v0.2.4 - Found bug that caused crash on Mac OS X 10.5 (but not 10.6).
* v0.2.4beta - Tracking bug that causes crash on Mac OS X 10.5 (but not 10.6).
* v0.2.3 - Fixed bug that caused all images to be saved as TIFF. Not sure when this bug was introduced.
* v0.2.2 - Added ability to output jpeg to standard out. Made executable lowercase imagesnap.
* v0.2.1 - Changed name from ImageCapture to ImageSnap to avoid confusion with Apple's Image Capture application.
* v0.2 - Multiple file formats (not just TIFF). Faster response.
* v0.1 - This is the initial release.

## A Note About Public Domain

I have released this software into the Public Domain. That means you can do
whatever you want with it. Really. You don't have to match it up with any other
open source license — just use it. You can rename the files, do whatever you
want. If your lawyers say you have to have a license, contact me, and I'll make
a special release to you under whatever reasonable license you desire: MIT, BSD,
GPL, whatever.
