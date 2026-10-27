import Foundation
import AVFoundation
let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
let video=root.appendingPathComponent("video/Booth编码原理与硬件实现_中文讲解.mp4")
let audio=root.appendingPathComponent("video/Booth编码讲解音频.m4a")
let temp=root.appendingPathComponent("video/Booth编码原理与硬件实现_双声道.mp4")
let va=AVURLAsset(url:video), aa=AVURLAsset(url:audio)
guard let vt=va.tracks(withMediaType:.video).first, let at=aa.tracks(withMediaType:.audio).first else { fatalError("Input tracks missing") }
let c=AVMutableComposition()
guard let v=c.addMutableTrack(withMediaType:.video,preferredTrackID:kCMPersistentTrackID_Invalid),
      let a=c.addMutableTrack(withMediaType:.audio,preferredTrackID:kCMPersistentTrackID_Invalid) else { fatalError("Output tracks unavailable") }
try v.insertTimeRange(CMTimeRange(start:.zero,duration:va.duration),of:vt,at:.zero)
try a.insertTimeRange(CMTimeRange(start:.zero,duration:aa.duration),of:at,at:.zero)
try? FileManager.default.removeItem(at:temp)
guard let exp=AVAssetExportSession(asset:c,presetName:AVAssetExportPresetPassthrough) else { fatalError("Exporter unavailable") }
exp.outputURL=temp; exp.outputFileType = .mp4; exp.shouldOptimizeForNetworkUse=true
let group=DispatchGroup();group.enter();exp.exportAsynchronously{group.leave()};group.wait()
if exp.status != .completed { fatalError("Export failed: \(String(describing:exp.error))") }
print(temp.path)
