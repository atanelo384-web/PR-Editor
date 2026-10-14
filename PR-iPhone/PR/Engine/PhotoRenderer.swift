import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// All operations use the original pixels, not a succession of recompressed previews.
enum PhotoRenderer {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    static func render(_ image: UIImage, state: PhotoState, maxDimension: CGFloat? = nil) -> UIImage? {
        let upright = normalize(image, maxDimension: maxDimension)
        guard let input = CIImage(image: upright) else { return nil }

        let color = CIFilter.colorControls()
        color.inputImage = input
        color.contrast = Float(state.contrast)
        color.saturation = Float(state.saturation)
        guard var output = color.outputImage else { return nil }

        let exposure = CIFilter.exposureAdjust()
        exposure.inputImage = output
        exposure.ev = Float(state.exposure)
        if let adjusted = exposure.outputImage { output = adjusted }

        if let filterName = state.look.filterName,
           let filter = CIFilter(name: filterName) {
            filter.setValue(output, forKey: kCIInputImageKey)
            if let filtered = filter.outputImage { output = filtered }
        }
        guard let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
        let filtered = UIImage(cgImage: cgImage)
        let transformed = transform(filtered, steps: state.rotation, mirrored: state.mirrored)
        let cropped = crop(transformed, aspect: state.crop.aspectRatio)
        return addText(state.textOverlay, to: cropped)
    }

    private static func normalize(_ image: UIImage, maxDimension: CGFloat?) -> UIImage {
        let original = image.size
        let ratio: CGFloat = maxDimension.map { min(1, $0 / max(original.width, original.height)) } ?? 1
        let size = CGSize(width: max(1, original.width * ratio), height: max(1, original.height * ratio))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func transform(_ image: UIImage, steps: Int, mirrored: Bool) -> UIImage {
        let normalizedSteps = (steps % 4 + 4) % 4
        if normalizedSteps == 0 && !mirrored { return image }
        let quarterTurn = normalizedSteps % 2 != 0
        let size = quarterTurn
            ? CGSize(width: image.size.height, height: image.size.width)
            : image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let context = ctx.cgContext
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.rotate(by: CGFloat(normalizedSteps) * .pi / 2)
            if mirrored { context.scaleBy(x: -1, y: 1) }
            image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2,
                                  width: image.size.width, height: image.size.height))
        }
    }

    private static func crop(_ image: UIImage, aspect: Double?) -> UIImage {
        guard let aspect, let cg = image.cgImage else { return image }
        let width = CGFloat(cg.width), height = CGFloat(cg.height)
        var cropWidth = width, cropHeight = height
        if width / height > aspect {
            cropWidth = height * aspect
        } else {
            cropHeight = width / aspect
        }
        let rect = CGRect(x: (width - cropWidth) / 2, y: (height - cropHeight) / 2,
                          width: cropWidth, height: cropHeight).integral
        guard let cut = cg.cropping(to: rect) else { return image }
        return UIImage(cgImage: cut)
    }

    private static func addText(_ text: String, to image: UIImage) -> UIImage {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = image.size
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
            let font = UIFont.systemFont(ofSize: max(18, size.width * 0.065), weight: .semibold)
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.9)
            shadow.shadowOffset = CGSize(width: 0, height: 2)
            shadow.shadowBlurRadius = max(3, size.width * 0.008)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: UIColor.white,
                .paragraphStyle: style, .shadow: shadow
            ]
            let width = size.width * 0.9
            let rect = CGRect(x: size.width * 0.05, y: size.height * 0.77,
                              width: width, height: size.height * 0.20)
            (text as NSString).draw(in: rect, withAttributes: attributes)
        }
    }
}
