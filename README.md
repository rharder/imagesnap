# Image Snap

by: Robert Harder

rob@iHarder.net

## Example

http://www.dayofthenewdan.com/projects/tlassemble

## Capture Images from the Command Line

http://iharder.net/imagesnap

ImageSnap is a Public Domain command-line tool that lets you capture still
images from an iSight or other video source.

## Installation

Copy the imagesnap file to someplace on your path like `/usr/local/bin`, or
leave it in a "current directory," and call it with `./imagesnap` instead.

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
iSight
DV
```

To select a specific video device use the -d device flag:

```
$ imagesnap -d DV
Capturing image from device "DV"..................snapshot.jpg
```

To output a jpeg representation to standard out (stdout), use a dash for the
filename:

```
$ ssh johndoe@somewhere.com /usr/local/bin/imagesnap - > snapshot.jpg
$ open snapshot.jpg
```

## Git Hook Usage

Add this to your git hooks in `.git/hooks/post-commit` and you'll be all set.

```rb
#!/usr/bin/env ruby
file="~/.gitshots/#{Time.now.to_i}.jpg"
puts "Taking capture into #{file}!"
system "imagesnap -q -w 3 #{file}"
exit 0
```

## Image Formats

The following image formats are supported and are determined by the filename
extension: JPEG, TIFF, PNG, GIF, BMP.

## Changes

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
