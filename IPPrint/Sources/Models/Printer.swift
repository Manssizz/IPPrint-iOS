import Foundation

struct Printer: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var hostname: String
    var port: Int
    var resourcePath: String
    var useSSL: Bool
    var makeAndModel: String?
    var location: String?
    var state: PrinterState
    var stateMessage: String?
    var supportsColor: Bool
    var supportsDuplex: Bool
    var supportedMediaSizes: [String]
    var supportedDocumentFormats: [String]
    var maxCopies: Int
    var supportsPageRanges: Bool
    var firmwareVersion: String?
    var serialNumber: String?
    var isManuallyAdded: Bool
    var lastSeen: Date
    var isFavorite: Bool
    
    var uri: String {
        let scheme = useSSL ? "ipps" : "ipp"
        let portString = (useSSL && port == 443) || (!useSSL && port == 631) ? "" : ":\(port)"
        return "\(scheme)://\(hostname)\(portString)\(resourcePath)"
    }
    
    var httpURL: URL? {
        let scheme = useSSL ? "https" : "http"
        let portString = (useSSL && port == 443) || (!useSSL && port == 631) ? "" : ":\(port)"
        return URL(string: "\(scheme)://\(hostname)\(portString)\(resourcePath)")
    }
    
    enum PrinterState: String, Codable {
        case idle = "idle"
        case processing = "processing"
        case stopped = "stopped"
        case unknown = "unknown"
        
        var displayName: String {
            switch self {
            case .idle: return "Ready"
            case .processing: return "Printing"
            case .stopped: return "Stopped"
            case .unknown: return "Unknown"
            }
        }
        
        var iconName: String {
            switch self {
            case .idle: return "checkmark.circle.fill"
            case .processing: return "printer.fill"
            case .stopped: return "exclamationmark.triangle.fill"
            case .unknown: return "questionmark.circle.fill"
            }
        }
        
        init(ippState: Int32) {
            switch ippState {
            case 3: self = .idle
            case 4: self = .processing
            case 5: self = .stopped
            default: self = .unknown
            }
        }
    }
    
    static func manual(name: String, hostname: String, port: Int = 631, path: String = "/ipp/print", ssl: Bool = false) -> Printer {
        Printer(
            id: UUID(),
            name: name,
            hostname: hostname,
            port: port,
            resourcePath: path,
            useSSL: ssl,
            makeAndModel: nil,
            location: nil,
            state: .unknown,
            stateMessage: nil,
            supportsColor: true,
            supportsDuplex: false,
            supportedMediaSizes: ["iso_a4_210x297mm", "na_letter_8.5x11in"],
            supportedDocumentFormats: ["application/pdf", "image/jpeg", "image/png"],
            maxCopies: 99,
            supportsPageRanges: true,
            firmwareVersion: nil,
            serialNumber: nil,
            isManuallyAdded: true,
            lastSeen: Date(),
            isFavorite: false
        )
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Printer, rhs: Printer) -> Bool {
        lhs.id == rhs.id
    }
}
