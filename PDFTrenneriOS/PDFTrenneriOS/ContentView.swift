import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import UIKit

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
    @Published var showPageJumpSheet = false
    @Published var detectedTitle = ""
    @Published var currentTitle = ""
    @Published var pageJumpInput = ""
    @Published var showFilePicker = false

    var pdfPath: String?
    private var numPages = 0
    private var hadSavedState = false

    func onAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showFilePicker = true
        }
    }

    func openFileChooser() {
        showFilePicker = true
    }

    func loadPDF(at url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let path = url.path
        splashMessage = "Lade: \(url.lastPathComponent)"

        guard FileManager.default.fileExists(atPath: path) else {
            errorMessage = "Datei nicht gefunden:\n\(path)"
            isLoading = false
            return
        }

        guard let doc = PDFDocument(url: url) else {
            errorMessage = "PDF konnte nicht geladen werden."
            isLoading = false
            return
        }

        document = doc
        numPages = doc.pageCount
        pdfPath = path
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

    func jumpToPagePrompt() {
        guard numPages > 0 else { return }
        pageJumpInput = "\(currentPage + 1)"
        showPageJumpSheet = true
    }

    func jumpToPage(_ pageNumber: Int) -> Bool {
        guard pageNumber >= 1, pageNumber <= numPages else {
            presentError(message: "Seitennummer muss zwischen 1 und \(numPages) liegen.")
            return false
        }
        currentPage = pageNumber - 1
        updateStatus()
        return true
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
            presentError(message: "Endseite kann nicht vor der Startseite liegen!")
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
                presentError(message: "Letzte Seite erreicht.")
            }
        } else {
            presentError(message: "Fehler beim Speichern der Extraktion.")
        }
    }

    func updateStatus() {
        let titleInfo = currentTitle.isEmpty ? "" : " | Titel: \(currentTitle)"
        statusText = "Seite \(currentPage + 1)/\(numPages) | Start: \(startPage + 1)\(titleInfo)"
    }

    func presentError(message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - ContentView
struct ContentView: View {
    @ObservedObject var vm: PDFViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isPadLayout: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        Group {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .fullScreenCover(isPresented: $vm.showFilePicker) {
            DocumentPicker { url in
                vm.showFilePicker = false
                vm.loadPDF(at: url)
            } onCancel: {
                vm.showFilePicker = false
                vm.errorMessage = "Keine Datei ausgewählt."
                vm.isLoading = false
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $vm.showTitleSheet) {
            TitleSheetView(vm: vm)
        }
        .sheet(isPresented: $vm.showPageJumpSheet) {
            PageJumpSheetView(vm: vm)
        }
        .alert("Fehler", isPresented: $vm.showError) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .onAppear { vm.onAppear() }
    }

    private var splashView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.richtext")
                .font(.system(size: isPadLayout ? 46 : 56))
                .foregroundColor(.accentColor)
            Text("PDFTrenner")
                .font(.system(size: isPadLayout ? 28 : 34, weight: .bold))
            Text(vm.splashMessage)
                .font(.system(size: isPadLayout ? 15 : 17))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: isPadLayout ? 36 : 44))
                .foregroundColor(.red)
            Text(msg)
                .font(.system(size: isPadLayout ? 16 : 18))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Datei auswählen…") {
                vm.openFileChooser()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pdfView: some View {
        VStack(spacing: 0) {
            iOSPDFKitView(document: vm.document, currentPage: vm.currentPage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            toolbarBar
                .frame(maxWidth: .infinity)
        }
    }

    private var toolbarBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Steuerung")
                        .font(.system(size: isPadLayout ? 13 : 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    statusText
                }

                Spacer(minLength: 12)

                pageNavButtons
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Spacer(minLength: 0)
                    actionButtons
                }

                VStack(alignment: .leading, spacing: 8) {
                    actionButtons
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private var pageNavButtons: some View {
        HStack(spacing: 8) {
            Button { vm.prevPage() } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(vm.currentPage == 0)

            Button { vm.nextPage() } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private var statusText: some View {
        Text(vm.statusText)
            .font(.system(size: isPadLayout ? 13 : 12, design: .monospaced))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundColor(.primary)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button { vm.setFirst() } label: {
                Label("Start", systemImage: "text.cursor")
                    .font(.system(size: isPadLayout ? 15 : 16, weight: .semibold))
                    .lineLimit(1)
                    .frame(minWidth: 128)
            }
            .buttonStyle(.borderedProminent)
            .fixedSize(horizontal: true, vertical: false)

            Button { vm.jumpToPagePrompt() } label: {
                Label("Seite", systemImage: "number")
                    .font(.system(size: isPadLayout ? 15 : 16, weight: .semibold))
                    .lineLimit(1)
                    .frame(minWidth: 128)
            }
            .buttonStyle(.bordered)
            .fixedSize(horizontal: true, vertical: false)

            Button { vm.setLast() } label: {
                Label("Ende", systemImage: "scissors")
                    .font(.system(size: isPadLayout ? 15 : 16, weight: .semibold))
                    .lineLimit(1)
                    .frame(minWidth: 128)
            }
            .buttonStyle(.bordered)
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}

// MARK: - Title Sheet
struct TitleSheetView: View {
    @ObservedObject var vm: PDFViewModel
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isPadLayout: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Startseite \(vm.startPage + 1) — Titel festlegen")
                    .font(.system(size: isPadLayout ? 18 : 19, weight: .semibold))
                    .multilineTextAlignment(.center)

                TextField("Songtitel", text: $vm.currentTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: isPadLayout ? 18 : 20))
                    .focused($isTextFieldFocused)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            isTextFieldFocused = true
                        }
                    }
                    .onChange(of: vm.detectedTitle) { newTitle in
                        if !newTitle.isEmpty && vm.currentTitle.isEmpty {
                            vm.currentTitle = newTitle
                        }
                    }
                    .submitLabel(.done)
                    .onSubmit { vm.confirmTitle() }

                HStack(spacing: 20) {
                    Button("Abbrechen") { vm.cancelTitle() }
                        .font(.system(size: isPadLayout ? 15 : 16, weight: .medium))
                    Button("OK") { vm.confirmTitle() }
                        .buttonStyle(.borderedProminent)
                        .font(.system(size: isPadLayout ? 15 : 16, weight: .semibold))
                }
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .navigationTitle("Titel festlegen")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Page Jump Sheet
struct PageJumpSheetView: View {
    @ObservedObject var vm: PDFViewModel
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isPadLayout: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Zu Seite springen")
                    .font(.system(size: isPadLayout ? 18 : 19, weight: .semibold))
                    .multilineTextAlignment(.center)

                TextField("Seitennummer", text: $vm.pageJumpInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: isPadLayout ? 18 : 20))
                    .keyboardType(.numberPad)
                    .focused($isTextFieldFocused)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isTextFieldFocused = true
                        }
                    }
                    .submitLabel(.go)
                    .onSubmit {
                        if let page = Int(vm.pageJumpInput.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            if vm.jumpToPage(page) {
                                vm.showPageJumpSheet = false
                            }
                        } else {
                            vm.presentError(message: "Bitte eine gültige Seitennummer eingeben.")
                        }
                    }

                HStack(spacing: 20) {
                    Button("Abbrechen") {
                        vm.showPageJumpSheet = false
                    }
                    .font(.system(size: isPadLayout ? 15 : 16, weight: .medium))

                    Button("Springen") {
                        let trimmed = vm.pageJumpInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let page = Int(trimmed) {
                            if vm.jumpToPage(page) {
                                vm.showPageJumpSheet = false
                            }
                        } else {
                            vm.presentError(message: "Bitte eine gültige Seitennummer eingeben.")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.system(size: isPadLayout ? 15 : 16, weight: .semibold))
                }
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .navigationTitle("Seite springen")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
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
        view.backgroundColor = UIColor.systemBackground
        return view
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
        }
        if let doc = document, currentPage >= 0 && currentPage < doc.pageCount,
           let page = doc.page(at: currentPage) {
            DispatchQueue.main.async {
                pdfView.go(to: page)
            }
        }
    }
}

// MARK: - File Picker
struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: (URL) -> Void
        private let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCancel()
                return
            }
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}
