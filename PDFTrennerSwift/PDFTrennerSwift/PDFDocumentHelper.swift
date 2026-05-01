import PDFKit

enum PDFDocumentHelper {
    static func extractPages(from document: PDFDocument, start: Int, end: Int) -> PDFDocument? {
        let newDoc = PDFDocument()
        var index = 0
        for i in start...end {
            guard let page = document.page(at: i) else { continue }
            newDoc.insert(page, at: index)
            index += 1
        }
        return newDoc
    }
}