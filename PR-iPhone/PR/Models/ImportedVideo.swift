import Foundation
import CoreTransferable
import UniformTypeIdentifiers

// PhotosPicker hands out a short-lived URL. Keep our own copy before it expires.
struct ImportedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copyURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
            try FileManager.default.copyItem(at: received.file, to: copyURL)
            return ImportedVideo(url: copyURL)
        }
    }
}
