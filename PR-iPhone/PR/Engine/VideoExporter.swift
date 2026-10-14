import Foundation
import AVFoundation

// A genuine trim with a volume-adjusted audio track. Orientation is preserved.
enum VideoExporter {
    static func export(input: URL, start: Double, end: Double, volume: Double) async throws -> URL {
        let asset = AVURLAsset(url: input)
        let duration = CMTimeGetSeconds(try await asset.load(.duration))
        guard duration.isFinite, end > start, start >= 0, end <= duration + 0.02 else {
            throw EditorError.invalidRange
        }
        let begin = CMTime(seconds: start, preferredTimescale: 600)
        let interval = CMTime(seconds: end - start, preferredTimescale: 600)
        let range = CMTimeRange(start: begin, duration: interval)
        let composition = AVMutableComposition()
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let sourceVideo = videoTracks.first,
              let destinationVideo = composition.addMutableTrack(withMediaType: .video,
                                                    preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw EditorError.noVideoTrack
        }
        try destinationVideo.insertTimeRange(range, of: sourceVideo, at: .zero)
        destinationVideo.preferredTransform = try await sourceVideo.load(.preferredTransform)

        var audioMix: AVMutableAudioMix?
        if let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first,
           let destinationAudio = composition.addMutableTrack(withMediaType: .audio,
                                               preferredTrackID: kCMPersistentTrackID_Invalid) {
            try destinationAudio.insertTimeRange(range, of: sourceAudio, at: .zero)
            let parameters = AVMutableAudioMixInputParameters(track: destinationAudio)
            parameters.setVolume(Float(max(0, min(1, volume))), at: .zero)
            let mix = AVMutableAudioMix()
            mix.inputParameters = [parameters]
            audioMix = mix
        }

        guard let session = AVAssetExportSession(asset: composition,
                                                 presetName: AVAssetExportPresetHighestQuality) else {
            throw EditorError.exportUnavailable
        }
        let output = try EditorFiles.newExportURL(extension: "mp4")
        session.outputURL = output
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        session.audioMix = audioMix
        guard session.supportedFileTypes.contains(.mp4) else { throw EditorError.exportUnavailable }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                if session.status == .completed {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: session.error ?? EditorError.exportUnavailable)
                }
            }
        }
        return output
    }
}
