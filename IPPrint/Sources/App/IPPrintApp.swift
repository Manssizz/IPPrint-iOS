import SwiftUI

@main
struct IPPrintApp: App {
    @StateObject private var printerVM = PrinterViewModel()
    @StateObject private var printJobVM = PrintJobViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(printerVM)
                .environmentObject(printJobVM)
        }
    }
}
