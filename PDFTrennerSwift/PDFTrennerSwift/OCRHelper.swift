import PDFKit
import AppKit

enum OCRHelper {
    static func recognizeTitle(from document: PDFDocument, pageIndex: Int) -> String {
        guard let page = document.page(at: pageIndex) else { return "" }

        let cropRect = page.bounds(for: .mediaBox)
        let cropHeight = cropRect.size.height * 0.10
        let croppedRect = CGRect(x: 0, y: cropRect.size.height - cropHeight, width: cropRect.size.width, height: cropHeight)

        guard let cgImage = renderCroppedImage(from: page, rect: croppedRect) else {
            print("OCR: konnte kein Bild rendern")
            return ""
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("pdftrenner_ocr_\(UUID().uuidString).png")

        guard let dest = CGImageDestinationCreateWithURL(tempURL as CFURL, "public.png" as CFString, 1, nil) else { return "" }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else { return "" }

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["tesseract", tempURL.path, "stdout", "-l", "deu+eng", "--psm", "6"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            let data = (process.standardOutput as? Pipe)?.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                print("OCR: tesseract exit \(process.terminationStatus)")
                return ""
            }
            guard let outputData = data, let text = String(data: outputData, encoding: .utf8) else { return "" }
            let cleaned = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
            print("OCR-Ergebnis: [\(cleaned)]")
            return cleaned
        } catch {
            print("OCR-Fehler: \(error.localizedDescription)")
            return ""
        }
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