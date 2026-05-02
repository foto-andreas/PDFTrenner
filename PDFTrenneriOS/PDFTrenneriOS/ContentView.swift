import SwiftUI
import PDFKit
import UniformTypeIdentifiers

// MARK: - ViewModel
class PDFViewModel: ObservableObject {
    @Published var document: PDFDocument?
    @Published var currentPage = 0
    @Published var startPage = 0
    @Published var endPage = 0
    @Published var statusText = ""
    @Published var isLoading = true
    @Published var splashMessage = "Anwendung wird gestartet…"
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showTitleSheet = false
    @Published var detectedTitle = ""
    @Published var currentTitle = ""

    var pdfPath: String?
    private var numPages = 0
    private var hadSavedState = false

    func onAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.openFileChooser() }
    }

    func openFileChooser() {
        errorMessage = nil
        let picker = DocumentPickerWrapper()
        picker.pick { [weak self] url in
            guard let self, let url else {
                self?.errorMessage = "Keine Datei ausgewählt."
                self?.isLoading = false
                return
            }
            self.pdfPath = url.path
            self.loadPDF(at: url.path)
        }
    }

    private func loadPDF(at path: String) {
        let file = URL(fileURLWithPath: path)
        splashMessage = "Lade: \(file.lastPathComponent)"

        guard FileManager.default.fileExists(atPath: path) else {
            errorMessage = "Datei nicht gefunden:\n\(path)"
            return
        }

        guard let doc = PDFDocument(url: file) else {
            errorMessage = "PDF konnte nicht geladen werden:\n\(path)"
            return
        }

        document = doc
        numPages = doc.pageCount
        splashMessage = "Bereite Renderer vor (\(numPages) Seiten)…"

        let saved = StateHelper.loadState(for: path)
        if saved >= 0 && saved < numPages {
            startPage = saved
            currentPage = saved
            hadSavedState = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isLoading = false
            self.updateStatus()
            if self.hadSavedState {
                self.setFirst()
            }
        }
    }

    func nextPage() {
        guard currentPage < numPages - 1 else { return }
        currentPage += 1
        updateStatus()
    }

    func prevPage() {
        guard currentPage > 0 else { return }
        currentPage -= 1
        updateStatus()
    }

    func setFirst() {
        startPage = currentPage
        updateStatus()
        detectedTitle = ""
        showTitleSheet = true
        runOCR()
    }

    func setLast() {
        endPage = currentPage
        if endPage < startPage {
            showError(message: "Endseite kann nicht vor der Startseite liegen!")
            return
        }
        saveSplit()
    }

    private func runOCR() {
        guard let doc = document, startPage < doc.pageCount else { return }
        let page = startPage
        DispatchQueue.global(qos: .userInitiated).async {
            let title = OCRHelper.recognizeTitle(from: doc, pageIndex: page)
            DispatchQueue.main.async {
                self.detectedTitle = title
            }
        }
    }

    func confirmTitle() {
        showTitleSheet = false
        updateStatus()
    }

    func cancelTitle() {
        currentTitle = ""
        showTitleSheet = false
        updateStatus()
    }

    func saveSplit() {
        guard let doc = document, let path = pdfPath else { return }
        let title = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        var safeTitle = title
            .replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue")
            .replacingOccurrences(of: "Ä", with: "Ae")
            .replacingOccurrences(of: "Ö", with: "Oe")
            .replacingOccurrences(of: "Ü", with: "Ue")
            .replacingOccurrences(of: "ß", with: "ss")
            .replacingOccurrences(of: "[^a-zA-Z0-9 _-]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if safeTitle.isEmpty {
            safeTitle = "Song_Seite_\(startPage + 1)"
        }

        let dir = URL(fileURLWithPath: path)
            .deletingLastPathComponent()
            .appendingPathComponent("Manual_Splits")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let outFile = dir.appendingPathComponent("\(safeTitle).pdf")

        if let savedDoc = PDFDocumentHelper.extractPages(from: doc, start: startPage, end: endPage) {
            savedDoc.write(to: outFile)

            StateHelper.saveState(startPage: startPage == endPage ? endPage : endPage, for: path)

            if endPage < numPages - 1 {
                currentPage = endPage + 1
                startPage = currentPage
                currentTitle = ""
                updateStatus()
                setFirst()
            } else {
                showError(message: "Letzte Seite erreicht.")
            }
        } else {
            showError(message: "Fehler beim Speichern der Extraktion.")
        }
    }

    func updateStatus() {
        let titleInfo = currentTitle.isEmpty ? "" : " | Titel: \(currentTitle)"
        statusText = "Seite: \(currentPage + 1) / \(numPages) | Start: Seite \(startPage + 1)\(titleInfo)"
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Document Picker Wrapper
class DocumentPickerWrapper: NSObject, UIDocumentPickerDelegate {
    private var completion: ((URL?) -> Void)?

    func pick(completion: @escaping (URL?) -> Void) {
        self.completion = completion
        let types = [UTType.pdf]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = self

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(picker, animated: true)
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        completion?(urls.first)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion?(nil)
    }
}

// MARK: - ContentView
struct ContentView: View {
    @ObservedObject var vm: PDFViewModel

    var body: some View {
        ZStack {
            if vm.isLoading {
                splashView
            } else if let error = vm.errorMessage, !vm.showTitleSheet {
                errorView(error)
            } else if vm.document != nil {
                pdfView
            } else {
                splashView
            }
        }
        .sheet(isPresented: $vm.showTitleSheet) {
            TitleSheetView(vm: vm)
        }
        .alert("Fehler", isPresented: $vm.showError) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .onAppear { vm.onAppear() }
    }

    private var splashView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("PDFTrenner")
                .font(.title2.bold())
            Text(vm.splashMessage)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundColor(.red)
            Text(msg)
                .font(.body)
                .multilineTextAlignment(.center)
            Button("Datei auswählen…") {
                vm.openFileChooser()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }

    private var pdfView: some View {
        VStack(spacing: 0) {
            iOSPDFKitView(document: vm.document, currentPage: vm.currentPage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 8) {
                Text(vm.statusText)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("◀") { vm.prevPage() }
                Button("▶") { vm.nextPage() }
                Button("Start (F)") { vm.setFirst() }
                    .buttonStyle(.borderedProminent)
                Button("Ende (L)") { vm.setLast() }
            }
            .padding(8)
            .background(Color(UIColor.secondarySystemBackground))
        }
    }
}

// MARK: - Title Sheet
struct TitleSheetView: View {
    @ObservedObject var vm: PDFViewModel
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                Text("Startseite \(vm.startPage + 1) — Titel:")
                    .font(.headline)

                TextField("Songtitel", text: $vm.currentTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .focused($isTextFieldFocused)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isTextFieldFocused = true
                        }
                    }
                    .onChange(of: vm.detectedTitle) { newTitle in
                        if !newTitle.isEmpty && vm.currentTitle.isEmpty {
                            vm.currentTitle = newTitle
                        }
                    }

                HStack(spacing: 16) {
                    Button("Abbrechen") {
                        vm.cancelTitle()
                    }
                    Button("OK") {
                        vm.confirmTitle()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
            .navigationTitle("Titel festlegen")
        }
        .presentationDetents([.medium])
    }
}

// MARK: - iOS PDFKit UIViewRepresentable
struct iOSPDFKitView: UIViewRepresentable {
    let document: PDFDocument?
    let currentPage: Int

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .vertical
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document !== document {
            uiView.document = document
        }
        if let doc = document, currentPage >= 0 && currentPage < doc.pageCount {
            if let page = doc.page(at: currentPage) {
                DispatchQueue.main.async {
                    uiView.go(to: page)
                }
            }
        }
    }
}