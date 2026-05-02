import SwiftUI
import PDFKit

class TitlePanelController: NSObject, NSTextFieldDelegate {
    private var panel: NSPanel?
    private weak var vm: PDFViewModel?
    private var textField: NSTextField?

    func show(vm: PDFViewModel, mainWindow: NSWindow?) {
        close()
        self.vm = vm

        let myPanel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 130),
                            styleMask: [.titled, .closable, .utilityWindow],
                            backing: .buffered, defer: false)
        myPanel.title = "Titel festlegen"
        myPanel.isFloatingPanel = true
        myPanel.level = .floating

        let headerLabel = NSTextField(labelWithString: "Startseite \(vm.startPage + 1) — Titel:")
        headerLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        let textField = NSTextField()
        textField.placeholderString = "Songtitel"
        textField.stringValue = vm.detectedTitle
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.lineBreakMode = .byTruncatingTail
        textField.tag = 100
        textField.delegate = self
        self.textField = textField

        let cancelButton = NSButton(title: "Abbrechen", target: self, action: #selector(cancelAction))
        cancelButton.bezelStyle = .roundRect
        cancelButton.keyEquivalent = "\u{1b}"

        let okButton = NSButton(title: "OK", target: self, action: #selector(confirmAction))
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r"

        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.addView(cancelButton, in: .trailing)
        buttonStack.addView(okButton, in: .trailing)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        stack.addView(headerLabel, in: .leading)
        stack.addView(textField, in: .leading)
        stack.addView(buttonStack, in: .trailing)

        myPanel.contentView = stack

        if let mainWindow = mainWindow {
            let mainFrame = mainWindow.frame
            let gap: CGFloat = 6
            let panelX = mainFrame.origin.x + mainFrame.width + gap
            let mainBottomY = mainFrame.origin.y
            myPanel.setFrameOrigin(NSPoint(x: panelX, y: mainBottomY))
        }

        myPanel.makeKeyAndOrderFront(nil)
        textField.becomeFirstResponder()
        textField.selectText(nil)

        self.panel = myPanel
    }

    func close() {
        textField = nil
        panel?.close()
        panel = nil
    }

    func updateTextField(_ text: String) {
        guard let tf = textField else { return }
        tf.stringValue = text
        tf.selectText(nil)
    }

    @objc private func confirmAction() {
        guard let textField = panel?.contentView?.viewWithTag(100) as? NSTextField else { return }
        vm?.currentTitle = textField.stringValue
        vm?.showSaveDialog = false
        vm?.updateStatus()
    }

    @objc private func cancelAction() {
        vm?.currentTitle = ""
        vm?.showSaveDialog = false
        vm?.updateStatus()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard obj.object is NSTextField else { return }
        if let event = NSApp.currentEvent, event.type == .keyDown, event.specialKey == .carriageReturn {
            confirmAction()
        }
    }
}

class PageJumpPanelController: NSObject, NSTextFieldDelegate {
    private var panel: NSPanel?
    private weak var vm: PDFViewModel?
    private var textField: NSTextField?

    func show(vm: PDFViewModel, mainWindow: NSWindow?) {
        close()
        self.vm = vm

        let myPanel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 130),
                              styleMask: [.titled, .closable, .utilityWindow],
                              backing: .buffered, defer: false)
        myPanel.title = "Seite springen"
        myPanel.isFloatingPanel = true
        myPanel.level = .floating

        let headerLabel = NSTextField(labelWithString: "Zu einer Seite im PDF springen:")
        headerLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        let textField = NSTextField()
        textField.placeholderString = "Seitennummer"
        textField.stringValue = "\(vm.currentPage + 1)"
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.lineBreakMode = .byTruncatingTail
        textField.tag = 100
        textField.delegate = self
        self.textField = textField

        let cancelButton = NSButton(title: "Abbrechen", target: self, action: #selector(cancelAction))
        cancelButton.bezelStyle = .roundRect
        cancelButton.keyEquivalent = "\u{1b}"

        let okButton = NSButton(title: "Springen", target: self, action: #selector(confirmAction))
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r"

        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.addView(cancelButton, in: .trailing)
        buttonStack.addView(okButton, in: .trailing)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        stack.addView(headerLabel, in: .leading)
        stack.addView(textField, in: .leading)
        stack.addView(buttonStack, in: .trailing)

        myPanel.contentView = stack

        if let mainWindow = mainWindow {
            let mainFrame = mainWindow.frame
            let gap: CGFloat = 6
            let panelX = mainFrame.origin.x + mainFrame.width + gap
            let mainBottomY = mainFrame.origin.y
            myPanel.setFrameOrigin(NSPoint(x: panelX, y: mainBottomY))
        }

        myPanel.makeKeyAndOrderFront(nil)
        textField.becomeFirstResponder()
        textField.selectText(nil)

        self.panel = myPanel
    }

    func close() {
        textField = nil
        panel?.close()
        panel = nil
    }

    @objc private func confirmAction() {
        guard let textField = panel?.contentView?.viewWithTag(100) as? NSTextField else { return }
        if let pageNumber = Int(textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
            if vm?.jumpToPage(pageNumber) == true {
                close()
            }
        } else {
            vm?.presentError(message: "Bitte eine gültige Seitennummer eingeben.")
        }
    }

    @objc private func cancelAction() {
        close()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard obj.object is NSTextField else { return }
        if let event = NSApp.currentEvent, event.type == .keyDown, event.specialKey == .carriageReturn {
            confirmAction()
        }
    }
}

struct ContentView: View {
    @StateObject private var vm = PDFViewModel()
    @State private var titlePanelController = TitlePanelController()
    @State private var pageJumpPanelController = PageJumpPanelController()

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
        .onReceive(vm.$showSaveDialog) { show in
            if show {
                let mainWindow = NSApp.windows.first(where: { $0.isVisible })
                titlePanelController.show(vm: vm, mainWindow: mainWindow)
            } else {
                titlePanelController.close()
            }
        }
        .onReceive(vm.$detectedTitle) { title in
            if !title.isEmpty {
                titlePanelController.updateTextField(title)
            }
        }
        .onReceive(vm.$showPageJumpPanel) { show in
            if show {
                let mainWindow = NSApp.windows.first(where: { $0.isVisible })
                pageJumpPanelController.show(vm: vm, mainWindow: mainWindow)
            } else {
                pageJumpPanelController.close()
            }
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
                Button("Start+F") { vm.setFirst() }
                    .keyboardShortcut("f", modifiers: [])
                Button("Seite") { vm.showPageJumpDialog() }
                Button("Ende+L") { vm.setLast() }
                    .keyboardShortcut("l", modifiers: [])
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
        }
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
                DispatchQueue.main.async {
                    nsView.go(to: page)
                }
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
    @Published var showPageJumpPanel = false
    @Published var detectedTitle = ""
    @Published var currentTitle = ""

    private var pdfPath: String?
    private var numPages = 0
    private var keyMonitor: Any?
    private var hadSavedState = false

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
            hadSavedState = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isLoading = false
            self.updateStatus()
            NSApp.activate(ignoringOtherApps: true)
            if self.hadSavedState {
                self.setFirst()
            }
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

    func showPageJumpDialog() {
        showPageJumpPanel = true
    }

    func jumpToPage(_ pageNumber: Int) -> Bool {
        guard pageNumber >= 1, pageNumber <= numPages else {
            let msg = "Seitennummer muss zwischen 1 und \(numPages) liegen."
            errorDetail = ErrorDetail(message: msg)
            showError = true
            return false
        }
        currentPage = pageNumber - 1
        updateStatus()
        return true
    }

    func setFirst() {
        startPage = currentPage
        updateStatus()
        print("Startseite gesetzt auf: \(startPage + 1)")
        detectedTitle = ""
        showSaveDialog = true
        runOCR()
    }

    func setLast() {
        endPage = currentPage
        if endPage < startPage {
            let msg = "Endseite kann nicht vor der Startseite liegen!"
            presentError(message: msg)
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
            print("Erfolgreich extrahiert: \(outFile.path)")

            StateHelper.saveState(startPage: startPage == endPage ? endPage : endPage, for: path)

            if endPage < numPages - 1 {
                currentPage = endPage + 1
                startPage = currentPage
                currentTitle = ""
                updateStatus()
                setFirst()
            } else {
                let msg = "Letzte Seite erreicht."
                presentError(message: msg)
            }
        } else {
            let msg = "Fehler beim Speichern der Extraktion."
            presentError(message: msg)
        }
    }

    func updateStatus() {
        let titleInfo = currentTitle.isEmpty ? "" : " | Titel: \(currentTitle)"
        statusText = "Seite: \(currentPage + 1) / \(numPages) | Start: Seite \(startPage + 1)\(titleInfo)"
    }

    func presentError(message: String) {
        errorDetail = ErrorDetail(message: message)
        showError = true
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
