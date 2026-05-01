import Foundation

enum StateHelper {
    static func loadState(for pdfPath: String) -> Int {
        let stateFile = stateFileURL(for: pdfPath)
        guard let data = FileManager.default.contents(atPath: stateFile.path) else { return -1 }
        let text = String(data: data, encoding: .utf8) ?? ""
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("startPage=") {
                let value = trimmed.replacingOccurrences(of: "startPage=", with: "")
                return Int(value) ?? -1
            }
        }
        return -1
    }

    static func saveState(startPage: Int, for pdfPath: String) {
        let stateFile = stateFileURL(for: pdfPath)
        let content = "#PDFTrenner State\nstartPage=\(startPage)\n"
        do {
            try content.write(to: stateFile, atomically: true, encoding: .utf8)
        } catch {
            print("Zustand konnte nicht gespeichert werden: \(error.localizedDescription)")
        }
    }

    private static func stateFileURL(for pdfPath: String) -> URL {
        let url = URL(fileURLWithPath: pdfPath)
        return url.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent + ".pdftrenner.state")
    }
}