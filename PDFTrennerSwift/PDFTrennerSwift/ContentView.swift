import SwiftUI
import PDFKit

struct ContentView: View {
    @StateObject private var vm = PDFViewModel()

    var body: some View {
        Group {
            if vm.isLoading {
                splashView
            } else if let error = vm.errorMessage {
                errorView(error)
            } else {
                pdfView
            }
        }
        .frame(minWidth: 600, minHeight: 700)
        .onAppear { vm.onAppear() }
        .sheet(isPresented: $vm.showSaveDialog) {
            saveDialog
        }
        .alert(isPresented: $vm.showError) {
            Alert(
                title: Text("Fehler"),
                message: Text(vm.errorDetail.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Splash
    private var splashView: some View {
        VStack(spacing: 12) {
            if let nsImage = NSImage(named: "AppIcon") {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
            }
            Text("PDFTrenner")
                .font(.title2.bold())
            Text(vm.splashMessage)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Error
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - PDF View
    private var pdfView: some View {
        VStack(spacing: 0) {
            PDFKitRepresentedView(document: vm.document, currentPage: vm.currentPage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .shadowColor))

            HStack(spacing: 8) {
                Text(vm.statusText)
                    .font(.system(.body, design: .monospaced))
                Spacer()
                Button(" ← ") { vm.prevPage() }
                Button(" → ") { vm.nextPage() }
                Button("Start (F)") { vm.setFirst() }
                    .keyboardShortcut("f", modifiers: [])
                Button("Ende (L)") { vm.setLast() }
                    .keyboardShortcut("l", modifiers: [])
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }

    // MARK: - Save Dialog
    private var saveDialog: some View {
        VStack(spacing: 12) {
            Text("Extraktion")
                .font(.headline)
            Text("Dateiname für Seiten \(vm.startPage + 1) bis \(vm.endPage + 1):")
            TextField("Songtitel", text: $vm.detectedTitle, onCommit: {
                vm.showSaveDialog = false
                vm.saveSplit()
            })
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 300)
            HStack {
                Button("Abbrechen") { vm.showSaveDialog = false }
                    .keyboardShortcut(.cancelAction)
                Button("Speichern") {
                    vm.showSaveDialog = false
                    vm.saveSplit()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

// MARK: - PDFKit NSViewRepresentable
struct PDFKitRepresentedView: NSViewRepresentable {
    let document: PDFDocument?
    let currentPage: Int

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .vertical
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document !== document {
            nsView.document = document
        }
        if let doc = document, currentPage >= 0 && currentPage < doc.pageCount {
            if let page = doc.page(at: currentPage) {
                nsView.go(to: page)
            }
        }
    }
}

// MARK: - Error Detail
struct ErrorDetail {
    let message: String
}

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
    @Published var errorDetail = ErrorDetail(message: "")
    @Published var showSaveDialog = false
    @Published var detectedTitle = ""

    private var pdfPath: String?
    private var numPages = 0
    private var keyMonitor: Any?

    func onAppear() {
        let args = CommandLine.arguments
        if args.count > 1 {
            let path = args[1]
            if path.hasPrefix("-") {
                splashMessage = "Öffne Dateiauswahl…"
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.openFileChooser() }
            } else {
                pdfPath = (path as NSString).expandingTildeInPath
                let resolved = URL(fileURLWithPath: pdfPath!).standardized.path
                pdfPath = resolved
                loadPDF(at: pdfPath!)
            }
        } else {
            splashMessage = "Öffne Dateiauswahl…"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.openFileChooser() }
        }
        installKeyMonitor()
    }

    // MARK: - File Chooser
    func openFileChooser() {
        let panel = NSOpenPanel()
        panel.title = "PDF-Datei auswählen"
        panel.allowedContentTypes = [.pdf]
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            pdfPath = url.path
            loadPDF(at: url.path)
        } else {
            errorMessage = "Keine Datei ausgewählt."
            isLoading = false
        }
    }

    // MARK: - Load PDF
    private func loadPDF(at path: String) {
        let file = URL(fileURLWithPath: path)
        splashMessage = "Lade: \(file.lastPathComponent)"

        guard FileManager.default.fileExists(atPath: path) else {
            errorMessage = "Datei nicht gefunden:\n\(path)"
            isLoading = false
            return
        }

        guard let doc = PDFDocument(url: file) else {
            errorMessage = "PDF konnte nicht geladen werden:\n\(path)"
            isLoading = false
            return
        }

        document = doc
        numPages = doc.pageCount
        splashMessage = "Bereite Renderer vor (\(numPages) Seiten)…\nErstelle Oberfläche…"

        let saved = StateHelper.loadState(for: path)
        if saved >= 0 && saved < numPages {
            startPage = saved
            currentPage = saved
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isLoading = false
            self.updateStatus()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Navigation
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
        print("Startseite gesetzt auf: \(startPage + 1)")
    }

    func setLast() {
        endPage = currentPage
        if endPage < startPage {
            let msg = "Endseite kann nicht vor der Startseite liegen!"
            errorDetail = ErrorDetail(message: msg)
            showError = true
            return
        }
        detectedTitle = ""
        showSaveDialog = true
        runOCR()
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

    func saveSplit() {
        guard let doc = document, let path = pdfPath else { return }
        let title = detectedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        var safeTitle = title.replacingOccurrences(of: "[^a-zA-Z0-9 _-]", with: "", options: .regularExpression)
        safeTitle = safeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
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
            print("Erfolgreich extrahiert: \(outFile.path)")

            StateHelper.saveState(startPage: startPage == endPage ? endPage : endPage, for: path)

            if endPage < numPages - 1 {
                currentPage = endPage + 1
                startPage = currentPage
                updateStatus()
            } else {
                let msg = "Letzte Seite erreicht."
                errorDetail = ErrorDetail(message: msg)
                showError = true
            }
        } else {
            let msg = "Fehler beim Speichern der Extraktion."
            errorDetail = ErrorDetail(message: msg)
            showError = true
        }
    }

    private func updateStatus() {
        statusText = "Seite: \(currentPage + 1) / \(numPages) | Start: Seite \(startPage + 1)"
    }

    // MARK: - Key Monitor
    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard !self.showSaveDialog else { return event }
            switch event.specialKey {
            case .leftArrow:
                self.prevPage()
                return nil
            case .rightArrow:
                self.nextPage()
                return nil
            default:
                break
            }
            if let chars = event.charactersIgnoringModifiers {
                switch chars.lowercased() {
                case "f":
                    self.setFirst()
                    return nil
                case "l":
                    self.setLast()
                    return nil
                default:
                    break
                }
            }
            return event
        }
    }

    deinit {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}