import AVFoundation
import CoreImage
import AppKit
import Foundation

// MARK: - Version

let VERSION = "0.3.0"

// MARK: - Command Line Argument Parser

struct Arguments {
    var showHelp: Bool = false
    var verbose: Bool = false
    var quiet: Bool = false
    var listDevices: Bool = false
    var deviceName: String? = nil
    var warmupDelay: Double = 3.0  // Default 3 seconds (matches v0.2.13+)
    var timelapse: Double? = nil   // Interval in seconds
    var maxCaptures: Int? = nil    // -n flag: limit number of timelapse pictures
    var filename: String = "snapshot.jpg"
    
    static func parse() -> Arguments? {
        var args = Arguments()
        let arguments = CommandLine.arguments
        var i = 1
        var positionalArgs: [String] = []
        
        while i < arguments.count {
            let arg = arguments[i]
            
            // Handle flags
            if arg.hasPrefix("-") && arg.count > 1 {
                switch arg {
                case "-h":
                    args.showHelp = true
                case "-v":
                    args.verbose = true
                case "-q":
                    args.quiet = true
                case "-l":
                    args.listDevices = true
                case "-d":
                    i += 1
                    if i >= arguments.count {
                        Output.error("Error: -d requires a device name argument.")
                        return nil
                    }
                    args.deviceName = arguments[i]
                case "-w":
                    i += 1
                    if i >= arguments.count {
                        Output.error("Error: -w requires a delay value.")
                        return nil
                    }
                    if let delay = Double(arguments[i]) {
                        args.warmupDelay = delay
                    } else {
                        Output.error("Error: -w requires a numeric value.")
                        return nil
                    }
                case "-t":
                    i += 1
                    if i >= arguments.count {
                        Output.error("Error: -t requires an interval value.")
                        return nil
                    }
                    if let interval = Double(arguments[i]) {
                        args.timelapse = interval
                    } else {
                        Output.error("Error: -t requires a numeric value.")
                        return nil
                    }
                case "-n":
                    i += 1
                    if i >= arguments.count {
                        Output.error("Error: -n requires a count value.")
                        return nil
                    }
                    if let count = Int(arguments[i]) {
                        args.maxCaptures = count
                    } else {
                        Output.error("Error: -n requires an integer value.")
                        return nil
                    }
                default:
                    Output.error("Error: Unknown option '" + arg + "'. Use -h for help.")
                    return nil
                }
            } else {
                // Positional argument - treat as filename
                positionalArgs.append(arg)
            }
            
            i += 1
        }
        
        // Use last positional argument as filename
        if !positionalArgs.isEmpty {
            args.filename = positionalArgs.last!
        }
        
        // Validate conflicting flags
        if args.quiet && args.verbose {
            Output.error("Error: Cannot use both -q and -v flags.")
            return nil
        }
        
        return args
    }
    
    static func printHelp() {
        let programName = (CommandLine.arguments[0] as NSString).lastPathComponent
        let help = """
        USAGE: \(programName) [options] [filename]
        Version: \(VERSION)
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
        """
        print(help)
    }
}

// MARK: - Output Helpers

class Output {
    static var quiet = false
    static var verbose = false
    
    static func log(_ message: String, terminator: String = "\n") {
        if !quiet {
            print(message, terminator: terminator)
            fflush(stdout)
        }
    }
    
    static func verboseLog(_ message: String) {
        if verbose && !quiet {
            print(message)
            fflush(stdout)
        }
    }
    
    static func error(_ message: String) {
        fputs("\(message)\n", stderr)
    }
}

// MARK: - Camera Manager

class CameraManager: NSObject {
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var currentDevice: AVCaptureDevice?
    private var capturedImage: NSImage?
    private var captureComplete = false
    private var captureError: Error?
    
    // Get all available video capture devices
    static func listDevices() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .externalUnknown
            ],
            mediaType: .video,
            position: .unspecified
        )
        return discoverySession.devices
    }
    
    static func printDeviceList() {
        let devices = listDevices()
        
        if devices.isEmpty {
            print("No video devices found.")
            return
        }
        
        print("Video Devices:")
        for device in devices {
            print("=> \(device.localizedName)")
        }
    }
    
    static func findDevice(matching name: String?) -> AVCaptureDevice? {
        let devices = listDevices()
        
        guard !devices.isEmpty else {
            return nil
        }
        
        // If no name specified, use first device
        guard let name = name else {
            return devices.first
        }
        
        // First try exact match
        if let exactMatch = devices.first(where: { $0.localizedName == name }) {
            return exactMatch
        }
        
        // Then try substring match (case-insensitive)
        let lowercaseName = name.lowercased()
        if let substringMatch = devices.first(where: { 
            $0.localizedName.lowercased().contains(lowercaseName) 
        }) {
            return substringMatch
        }
        
        return nil
    }
    
    var deviceName: String {
        return currentDevice?.localizedName ?? "Unknown"
    }
    
    func setupSession(device: AVCaptureDevice) -> Bool {
        currentDevice = device
        
        Output.verboseLog("Setting up capture session for device: \(device.localizedName)")
        
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            
            if captureSession?.canAddInput(input) == true {
                captureSession?.addInput(input)
            } else {
                Output.error("Error: Cannot add camera input to session.")
                return false
            }
            
            photoOutput = AVCapturePhotoOutput()
            
            if let photoOutput = photoOutput,
               captureSession?.canAddOutput(photoOutput) == true {
                captureSession?.addOutput(photoOutput)
            } else {
                Output.error("Error: Cannot add photo output to session.")
                return false
            }
            
            return true
            
        } catch {
            Output.error("Error setting up camera: \(error.localizedDescription)")
            return false
        }
    }
    
    func startSession() {
        Output.verboseLog("Starting capture session...")
        captureSession?.startRunning()
    }
    
    func stopSession() {
        Output.verboseLog("Stopping capture session...")
        captureSession?.stopRunning()
    }
    
    func capturePhoto() -> NSImage? {
        capturedImage = nil
        captureComplete = false
        captureError = nil
        
        guard let photoOutput = photoOutput else {
            Output.error("Error: Photo output not configured.")
            return nil
        }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        
        photoOutput.capturePhoto(with: settings, delegate: self)
        
        // Wait for capture to complete
        let timeout = Date().addingTimeInterval(10.0)
        while !captureComplete && Date() < timeout {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        }
        
        if let error = captureError {
            Output.error("Capture error: \(error.localizedDescription)")
            return nil
        }
        
        return capturedImage
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        defer { captureComplete = true }
        
        if let error = error {
            captureError = error
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            Output.error("Error: Could not get image data from photo.")
            return
        }
        
        capturedImage = NSImage(data: imageData)
    }
}

// MARK: - Filename Utilities

func generateTimelapseFilename(base: String, index: Int) -> String {
    let url = URL(fileURLWithPath: base)
    let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
    let nameWithoutExt = url.deletingPathExtension().path
    
    // Format: snapshot-00001.jpg (5 digit padding like original)
    let paddedIndex = String(format: "%05d", index)
    
    return "\(nameWithoutExt)-\(paddedIndex).\(ext)"
}

func findStartingSequenceNumber(base: String) -> Int {
    // Check existing files and find where to continue numbering
    let url = URL(fileURLWithPath: base)
    let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
    let nameWithoutExt = url.deletingPathExtension().lastPathComponent
    let directory = url.deletingLastPathComponent().path
    let workingDir = directory.isEmpty ? "." : directory
    
    let fileManager = FileManager.default
    var maxNumber = 0
    
    do {
        let files = try fileManager.contentsOfDirectory(atPath: workingDir)
        let pattern = "\(nameWithoutExt)-(\\d+)\\.\(ext)"
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        
        for file in files {
            let range = NSRange(file.startIndex..., in: file)
            if let match = regex.firstMatch(in: file, options: [], range: range),
               let numberRange = Range(match.range(at: 1), in: file),
               let number = Int(file[numberRange]) {
                maxNumber = max(maxNumber, number)
            }
        }
    } catch {
        // Ignore errors, start from 1
    }
    
    return maxNumber + 1
}

// MARK: - Path Validation

func validateOutputPath(_ path: String) -> String? {
    // Empty path is invalid
    guard !path.isEmpty else {
        Output.error("Error: Output path cannot be empty.")
        return nil
    }
    
    // Get the current working directory
    let currentDir = FileManager.default.currentDirectoryPath
    
    // Resolve the full path (expands tilde, resolves relative paths)
    let fullPath: String
    if path.hasPrefix("/") {
        // Absolute path
        fullPath = path
    } else {
        // Relative path - resolve from current directory
        fullPath = (currentDir as NSString).appendingPathComponent(path)
    }
    
    // Expand tilde
    let expandedPath = (fullPath as NSString).expandingTildeInPath
    
    // Resolve symlinks
    let url = URL(fileURLWithPath: expandedPath)
    let resolvedURL = url.resolvingSymlinksInPath()
    let resolvedPath = resolvedURL.path
    
    // Check for path traversal - ensure the resolved path is within current directory
    // or is a direct child of current directory for absolute paths starting with /
    // For security, we allow absolute paths but warn about them
    
    // Check if the path contains ".." components (path traversal attempt)
    let pathComponents = resolvedPath.components(separatedBy: "/")
    if pathComponents.contains("..") {
        Output.error("Error: Invalid output path - path traversal detected.")
        return nil
    }
    
    // For relative paths, ensure they stay within current directory
    if !path.hasPrefix("/") {
        let currentDirURL = URL(fileURLWithPath: currentDir)
        let resolvedCurrentDir = currentDirURL.resolvingSymlinksInPath()
        
        // Check if resolved path starts with current directory
        if !resolvedPath.hasPrefix(resolvedCurrentDir.path) {
            Output.error("Error: Output path must be within current directory.")
            return nil
        }
    }
    
    // Check if parent directory exists and is writable
    let parentDir = resolvedURL.deletingLastPathComponent()
    let fileManager = FileManager.default
    
    var isDirectory: ObjCBool = false
    if fileManager.fileExists(atPath: parentDir.path, isDirectory: &isDirectory) {
        if !isDirectory.boolValue {
            Output.error("Error: Parent path is not a directory.")
            return nil
        }
    } else {
        // Try to create parent directory
        do {
            try fileManager.createDirectory(atPath: parentDir.path, withIntermediateDirectories: true)
        } catch {
            Output.error("Error: Cannot create parent directory: \(error.localizedDescription)")
            return nil
        }
    }
    
    return resolvedPath
}

// MARK: - Atomic File Write

func saveImageAtomically(_ image: NSImage, to finalPath: String) -> Bool {
    // Validate the path first
    guard let resolvedPath: String = validateOutputPath(finalPath) else {
        return false
    }
    
    guard let tiffData = image.tiffRepresentation,
          let bitmapRep = NSBitmapImageRep(data: tiffData) else {
        Output.error("Error: Could not process image data.")
        return false
    }
    
    let fileExtension = (finalPath as NSString).pathExtension.lowercased()
    let fileType: NSBitmapImageRep.FileType
    var properties: [NSBitmapImageRep.PropertyKey: Any] = [:]
    
    switch fileExtension {
    case "png":
        fileType = .png
    case "tiff", "tif":
        fileType = .tiff
    case "bmp":
        fileType = .bmp
    case "gif":
        fileType = .gif
    default:
        fileType = .jpeg
        properties[.compressionFactor] = 0.9
    }
    
    guard let imageData = bitmapRep.representation(using: fileType, properties: properties) else {
        Output.error("Error: Could not encode image.")
        return false
    }
    
    do {
        // Create a temporary file in the same directory
        let finalURL = URL(fileURLWithPath: resolvedPath)
        let tempURL = finalURL.appendingPathExtension("tmp")
        
        // Write to temp file
        try imageData.write(to: tempURL)
        
        // Atomically move to final location
        try FileManager.default.moveItem(at: tempURL, to: finalURL)
        
        return true
    } catch {
        Output.error("Error saving image: \(error.localizedDescription)")
        return false
    }
}

// MARK: - Main Execution

func main() -> Int32 {
    guard let args = Arguments.parse() else {
        return 1
    }
    
    Output.quiet = args.quiet
    Output.verbose = args.verbose
    
    if args.showHelp {
        Arguments.printHelp()
        return 0
    }
    
    if args.listDevices {
        CameraManager.printDeviceList()
        return 0
    }
    
    // Check camera authorization status
    let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
    
    switch authStatus {
    case .denied, .restricted:
        Output.error("Error: Camera access denied. Please grant permission in System Preferences > Privacy > Camera.")
        return 1
    case .notDetermined:
        // Request permission synchronously for CLI
        let semaphore = DispatchSemaphore(value: 0)
        var granted = false
        AVCaptureDevice.requestAccess(for: .video) { result in
            granted = result
            semaphore.signal()
        }
        semaphore.wait()
        if !granted {
            Output.error("Error: Camera access not granted.")
            return 1
        }
    case .authorized:
        break
    @unknown default:
        break
    }
    
    // Find the device
    guard let device = CameraManager.findDevice(matching: args.deviceName) else {
        if let name = args.deviceName {
            Output.error("Error: No video device found matching \"\(name)\"")
        } else {
            Output.error("Error: No video devices available.")
        }
        return 1
    }
    
    let camera = CameraManager()
    
    guard camera.setupSession(device: device) else {
        return 1
    }
    
    camera.startSession()
    
    // Print capturing message with dots for warmup
    Output.log("Capturing image from device \"\(camera.deviceName)\"", terminator: "")
    
    // Warmup with visual dots
    if args.warmupDelay > 0 {
        let dotInterval = 0.1
        let totalDots = Int(args.warmupDelay / dotInterval)
        for _ in 0..<totalDots {
            Output.log(".", terminator: "")
            Thread.sleep(forTimeInterval: dotInterval)
        }
    }
    
    // Handle timelapse mode
    if let interval = args.timelapse {
        var captureCount = 0
        var sequenceNumber = findStartingSequenceNumber(base: args.filename)
        
        // Set up signal handler for graceful exit
        signal(SIGINT) { _ in
            Output.log("\nTimelapse stopped.")
            exit(0)
        }
        
        while true {
            captureCount += 1
            
            // Check if we've reached the limit
            if let maxCaptures = args.maxCaptures, captureCount > maxCaptures {
                break
            }
            
            let outputPath = generateTimelapseFilename(base: args.filename, index: sequenceNumber)
            
            guard let image = camera.capturePhoto() else {
                Output.error("Error: Failed to capture photo.")
                camera.stopSession()
                return 1
            }
            
            if saveImageAtomically(image, to: outputPath) {
                Output.log(outputPath)
            } else {
                Output.error("Error: Failed to save image to \(outputPath)")
                camera.stopSession()
                return 1
            }
            
            sequenceNumber += 1
            
            // Check again if we've reached the limit before sleeping
            if let maxCaptures = args.maxCaptures, captureCount >= maxCaptures {
                break
            }
            
            // Wait for next capture
            Thread.sleep(forTimeInterval: interval)
        }
    } else {
        // Single capture mode
        guard let image = camera.capturePhoto() else {
            Output.error("Error: Failed to capture photo.")
            camera.stopSession()
            return 1
        }
        
        if saveImageAtomically(image, to: args.filename) {
            Output.log(args.filename)
        } else {
            Output.error("Error: Failed to save image to \(args.filename)")
            camera.stopSession()
            return 1
        }
    }
    
    camera.stopSession()
    
    return 0
}

// Run the program
exit(main())
