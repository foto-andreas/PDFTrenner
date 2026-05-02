import SwiftUI

@main
struct PDFTrennerApp: App {
    @StateObject private var vm = PDFViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(vm: vm)
        }
    }
}