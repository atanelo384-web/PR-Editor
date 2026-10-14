import AVFoundation
import Combine
import Foundation
import UIKit

enum EditorError: LocalizedError {
    case invalidImage, invalidRange, noVideoTrack, exportUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Невозможно открыть изображение или сохранить JPEG."
        case .invalidRange: return "Неверные границы видеофрагмента."
        case .noVideoTrack: return "В файле отсутствует видеодорожка."
        case .exportUnavailable: return "Экспорт видео недоступен для этого файла."
        }
    }
}

enum EditorFiles {
    static func exportDirectory() throws -> URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func newExportURL(extension ext: String) throws -> URL {
        try exportDirectory().appendingPathComponent("PR-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(5))")
            .appendingPathExtension(ext)
    }

    static func importCopy(_ url: URL) throws -> URL {
        let canAccess = url.startAccessingSecurityScopedResource()
        defer { if canAccess { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
        let target = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        try FileManager.default.copyItem(at: url, to: target)
        return target
    }

    static func imageFromFile(_ url: URL) throws -> UIImage {
        let canAccess = url.startAccessingSecurityScopedResource()
        defer { if canAccess { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        guard let image = UIImage(data: data) else { throw EditorError.invalidImage }
        return image
    }
}

@MainActor
final class EditorProject: ObservableObject {
    @Published private(set) var originalPhoto: UIImage?
    @Published private(set) var photoPreview: UIImage?
    @Published var photoState = PhotoState() {
        didSet { refreshPhotoPreview() }
    }
    @Published private(set) var undoStack: [PhotoState] = []
    @Published private(set) var redoStack: [PhotoState] = []
    private var continuousInitialState: PhotoState?

    @Published private(set) var videoURL: URL?
    @Published private(set) var videoDuration: Double = 0
    @Published var trimStart: Double = 0
    @Published var trimEnd: Double = 0
    @Published var volume: Double = 1
    @Published var videoPlayer: AVPlayer?
    @Published var isExporting = false
    @Published var exportURL: URL?
    @Published var errorMessage: String?

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func loadPhoto(_ image: UIImage) {
        originalPhoto = image
        undoStack.removeAll()
        redoStack.removeAll()
        continuousInitialState = nil
        photoState = PhotoState()
        exportURL = nil
    }

    private func refreshPhotoPreview() {
        guard let originalPhoto else { photoPreview = nil; return }
        photoPreview = PhotoRenderer.render(originalPhoto, state: photoState, maxDimension: 1100)
    }

    func editPhoto(_ edit: (inout PhotoState) -> Void) {
        let before = photoState
        edit(&photoState)
        if photoState != before {
            undoStack.append(before)
            redoStack.removeAll()
        }
    }

    func beginContinuousEdit() {
        if continuousInitialState == nil { continuousInitialState = photoState }
    }

    func endContinuousEdit() {
        guard let before = continuousInitialState else { return }
        continuousInitialState = nil
        if before != photoState {
            undoStack.append(before)
            redoStack.removeAll()
        }
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(photoState)
        photoState = previous
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(photoState)
        photoState = next
    }

    func resetPhoto() { editPhoto { $0 = PhotoState() } }

    func exportPhoto() throws {
        guard let image = originalPhoto,
              let result = PhotoRenderer.render(image, state: photoState),
              let jpeg = result.jpegData(compressionQuality: 0.94) else { throw EditorError.invalidImage }
        let url = try EditorFiles.newExportURL(extension: "jpg")
        try jpeg.write(to: url, options: .atomic)
        exportURL = url
    }

    func loadVideo(_ url: URL) async throws {
        let localURL = try EditorFiles.importCopy(url)
        try await loadLocalVideo(localURL)
    }

    func loadLocalVideo(_ url: URL) async throws {
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(try await asset.load(.duration))
        guard duration.isFinite, duration >= 0.1,
              !(try await asset.loadTracks(withMediaType: .video)).isEmpty else {
            throw EditorError.noVideoTrack
        }
        videoPlayer?.pause()
        videoURL = url
        videoDuration = duration
        trimStart = 0
        trimEnd = duration
        volume = 1
        videoPlayer = AVPlayer(url: url)
        exportURL = nil
    }

    func seek(to seconds: Double) {
        videoPlayer?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600),
                          toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func togglePlayback() {
        guard let videoPlayer else { return }
        if videoPlayer.timeControlStatus == .playing {
            videoPlayer.pause()
        } else {
            let current = CMTimeGetSeconds(videoPlayer.currentTime())
            if current >= trimEnd - 0.05 || current < trimStart { seek(to: trimStart) }
            videoPlayer.play()
        }
    }

    func exportVideo() async {
        guard let videoURL else { return }
        isExporting = true
        defer { isExporting = false }
        do {
            exportURL = try await VideoExporter.export(input: videoURL, start: trimStart,
                                                       end: trimEnd, volume: volume)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
