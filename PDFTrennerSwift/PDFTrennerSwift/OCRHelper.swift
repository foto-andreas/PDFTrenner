import PDFKit
import AppKit
import Vision

enum OCRHelper {
    static func captureTitleImage(from document: PDFDocument, pageIndex: Int) -> CGImage? {
        guard let page = document.page(at: pageIndex) else { return nil }

        let cropRect = page.bounds(for: .mediaBox)
        let cropHeight = cropRect.size.height * 0.10
        let croppedRect = CGRect(x: 0, y: cropRect.size.height - cropHeight, width: cropRect.size.width, height: cropHeight)

        guard let cgImage = renderCroppedImage(from: page, rect: croppedRect) else {
            print("OCR: konnte kein Bild rendern")
            return nil
        }

        return cgImage
    }

    static func recognizeTitle(from image: CGImage) -> String {
        performVisionOCR(on: image)
    }

    static func recognizeTitle(from document: PDFDocument, pageIndex: Int) -> String {
        guard let cgImage = captureTitleImage(from: document, pageIndex: pageIndex) else {
            return ""
        }
        return performVisionOCR(on: cgImage)
    }

    private static func performVisionOCR(on cgImage: CGImage) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["de", "en"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Vision OCR Fehler: \(error.localizedDescription)")
            return ""
        }

        guard let observations = request.results else { return "" }

        let text = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }.joined(separator: " ")

        let cleaned = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        print("OCR-Ergebnis (Vision): [\(cleaned)]")
        return cleaned
    }

    private static func renderCroppedImage(from page: PDFPage, rect: CGRect) -> CGImage? {
        let scale: CGFloat = 2.0
        let width = Int(rect.width * scale)
        let height = Int(rect.height * scale)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -rect.origin.x, y: -rect.origin.y)
        page.draw(with: .mediaBox, to: context)

        return context.makeImage()
    }
}
