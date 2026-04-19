import Foundation

class PrinterStorage: ObservableObject {
    static let shared = PrinterStorage()
    
    @Published var savedPrinters: [Printer] = []
    
    private let key = "saved_printers"
    
    init() {
        load()
    }
    
    func save(_ printer: Printer) {
        if let idx = savedPrinters.firstIndex(where: { $0.id == printer.id }) {
            savedPrinters[idx] = printer
        } else {
            savedPrinters.append(printer)
        }
        persist()
    }
    
    func remove(_ printer: Printer) {
        savedPrinters.removeAll { $0.id == printer.id }
        persist()
    }
    
    func toggleFavorite(_ printer: Printer) {
        if let idx = savedPrinters.firstIndex(where: { $0.id == printer.id }) {
            savedPrinters[idx].isFavorite.toggle()
            persist()
        }
    }
    
    func isSaved(_ printer: Printer) -> Bool {
        savedPrinters.contains { $0.hostname == printer.hostname && $0.port == printer.port }
    }
    
    func defaultPrinter() -> Printer? {
        savedPrinters.first { $0.isFavorite } ?? savedPrinters.first
    }
    
    private func persist() {
        if let data = try? JSONEncoder().encode(savedPrinters) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let printers = try? JSONDecoder().decode([Printer].self, from: data) {
            savedPrinters = printers
        }
    }
}
