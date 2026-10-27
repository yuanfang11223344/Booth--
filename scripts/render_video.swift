import Foundation
import AVFoundation
import CoreImage
import ImageIO
import CoreVideo

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let dir = root.appendingPathComponent("video")
let tempVideo = dir.appendingPathComponent("silent.mp4")
let output = dir.appendingPathComponent("Booth编码原理与硬件实现_中文讲解.mp4")
let dims = (width: 1280, height: 720)
let lines = try String(contentsOf: dir.appendingPathComponent("frames.ffconcat"), encoding: .utf8).split(separator: "\n")
var frames: [(URL, Double)] = []
var pending: URL? = nil
for line in lines {
    if line.hasPrefix("file '") {
        let path = String(line.dropFirst(6).dropLast())
        pending = URL(fileURLWithPath: path)
    } else if line.hasPrefix("duration "), let p = pending, let seconds = Double(line.dropFirst(9)) {
        frames.append((p, seconds)); pending = nil
    }
}
if frames.isEmpty { fatalError("No slide durations") }
try? FileManager.default.removeItem(at: tempVideo)
let writer = try AVAssetWriter(outputURL: tempVideo, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: dims.width,
    AVVideoHeightKey: dims.height,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 1_500_000]
])
input.expectsMediaDataInRealTime = false
let attrs: [String: Any] = [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
    kCVPixelBufferWidthKey as String: dims.width,
    kCVPixelBufferHeightKey as String: dims.height,
    kCVPixelBufferCGImageCompatibilityKey as String: true,
    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
]
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs)
writer.add(input)
if !writer.startWriting() { fatalError("Writer start failed: \(String(describing: writer.error))") }
writer.startSession(atSourceTime: .zero)
func pixel(_ url: URL) -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    let result = CVPixelBufferCreate(kCFAllocatorDefault, dims.width, dims.height,
                                     kCVPixelFormatType_32ARGB, attrs as CFDictionary, &buffer)
    guard result == kCVReturnSuccess, let b = buffer else { fatalError("pixel buffer allocation failed") }
    CVPixelBufferLockBaseAddress(b, [])
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(b), width: dims.width, height: dims.height,
                              bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(b), space: cs,
                              bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue),
          let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { fatalError("Cannot draw \(url.path)") }
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: dims.width, height: dims.height))
    CVPixelBufferUnlockBaseAddress(b, [])
    return b
}
var seconds = 0.0
for (url, duration) in frames {
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.01) }
    let t = CMTime(seconds: seconds, preferredTimescale: 600)
    if !adaptor.append(pixel(url), withPresentationTime: t) { fatalError("append failed: \(String(describing: writer.error))") }
    seconds += duration
}
while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.01) }
_ = adaptor.append(pixel(frames.last!.0), withPresentationTime: CMTime(seconds: seconds, preferredTimescale: 600))
while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.01) }
_ = adaptor.append(pixel(frames.last!.0), withPresentationTime: CMTime(seconds: seconds + 1.0 / 24.0, preferredTimescale: 600))
input.markAsFinished()
let group = DispatchGroup(); group.enter()
writer.finishWriting { group.leave() }
group.wait()
if writer.status != .completed { fatalError("Writer failed: \(String(describing: writer.error))") }
print("Silent MP4: \(seconds) seconds")

let composition = AVMutableComposition()
let videoAsset = AVURLAsset(url: tempVideo)
guard let srcVideo = videoAsset.tracks(withMediaType: .video).first,
      let dstVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
      let dstAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { fatalError("Cannot create composition tracks") }
try dstVideo.insertTimeRange(CMTimeRange(start: .zero, duration: videoAsset.duration), of: srcVideo, at: .zero)
var cursor = CMTime.zero
for i in 1...frames.count {
    let url = dir.appendingPathComponent(String(format: "audio/%02d.aiff", i))
    let asset = AVURLAsset(url: url)
    guard let track = asset.tracks(withMediaType: .audio).first else { fatalError("No audio track at \(url.path)") }
    try dstAudio.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: track, at: cursor)
    cursor = CMTimeAdd(cursor, asset.duration)
}
try? FileManager.default.removeItem(at: output)
guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { fatalError("No exporter") }
exporter.outputURL = output
exporter.outputFileType = .mp4
let exportGroup = DispatchGroup(); exportGroup.enter()
exporter.exportAsynchronously { exportGroup.leave() }
exportGroup.wait()
if exporter.status != .completed { fatalError("Export failed: \(String(describing: exporter.error))") }
print("Created \(output.path)")
