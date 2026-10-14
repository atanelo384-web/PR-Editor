import Foundation

enum CropMode: String, CaseIterable, Identifiable {
    case original = "Оригинал"
    case square = "1:1"
    case portrait = "4:5"
    case landscape = "16:9"
    var id: String { rawValue }
    var aspectRatio: Double? {
        switch self {
        case .original: return nil
        case .square: return 1
        case .portrait: return 4.0 / 5.0
        case .landscape: return 16.0 / 9.0
        }
    }
}

enum ImageLook: String, CaseIterable, Identifiable {
    case standard = "Обычный"
    case mono = "Моно"
    case instant = "Плёнка"
    case chrome = "Хром"
    var id: String { rawValue }
    var filterName: String? {
        switch self {
        case .standard: return nil
        case .mono: return "CIPhotoEffectMono"
        case .instant: return "CIPhotoEffectInstant"
        case .chrome: return "CIPhotoEffectChrome"
        }
    }
}

struct PhotoState: Equatable {
    var exposure: Double = 0
    var contrast: Double = 1
    var saturation: Double = 1
    var rotation: Int = 0
    var mirrored: Bool = false
    var crop: CropMode = .original
    var look: ImageLook = .standard
    var textOverlay: String = ""
}
