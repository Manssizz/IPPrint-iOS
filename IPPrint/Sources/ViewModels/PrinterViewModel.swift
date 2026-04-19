import Foundation
import SwiftUI

@MainActor
class PrinterViewModel: ObservableObject {
    @Published var selectedPrinter: Printer?
    @Published var printerInfo: Printer?
    @Published var isLoading = false
    @Published var error: String?
    @Published var showError = false
    
    private let ippService = IPPService.shared
    let storage = PrinterStorage.shared
    
    func selectPrinter(_ printer: Printer) {
        selectedPrinter = printer
        refreshPrinterInfo()
    }
    
    func refreshPrinterInfo() {
        guard let printer = selectedPrinter else { return }
        
        isLoading = true
        error = nil
        
        Task {
            do {
                let updated = try await ippService.getPrinterAttributes(printer: printer)
                self.printerInfo = updated
                self.selectedPrinter = updated
                
                // Update stored printer
                if storage.isSaved(printer) {
                    storage.save(updated)
                }
            } catch {
                self.error = error.localizedDescription
                self.showError = true
                self.printerInfo = printer
            }
            self.isLoading = false
        }
    }
    
    func savePrinter(_ printer: Printer) {
        storage.save(printer)
    }
    
    func removePrinter(_ printer: Printer) {
        storage.remove(printer)
        if selectedPrinter?.id == printer.id {
            selectedPrinter = storage.defaultPrinter()
        }
    }
    
    func addManualPrinter(name: String, hostname: String, port: Int, path: String, ssl: Bool) {
        let printer = Printer.manual(name: name, hostname: hostname, port: port, path: path, ssl: ssl)
        storage.save(printer)
        selectPrinter(printer)
    }
}
