import Foundation

struct PrintJob: Identifiable {
    let id: UUID
    var jobId: Int32?
    var printerName: String
    var documentName: String
    var documentData: Data
    var documentMimeType: String
    var settings: PrintSettings
    var status: JobStatus
    var statusMessage: String?
    var submittedAt: Date
    var completedAt: Date?
    var pageCount: Int?
    
    enum JobStatus: String {
        case pending = "pending"
        case processing = "processing"
        case completed = "completed"
        case cancelled = "cancelled"
        case failed = "failed"
        case held = "held"
        case aborted = "aborted"
        
        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .processing: return "Printing..."
            case .completed: return "Completed"
            case .cancelled: return "Cancelled"
            case .failed: return "Failed"
            case .held: return "Held"
            case .aborted: return "Aborted"
            }
        }
        
        var iconName: String {
            switch self {
            case .pending: return "clock.fill"
            case .processing: return "printer.fill"
            case .completed: return "checkmark.circle.fill"
            case .cancelled: return "xmark.circle.fill"
            case .failed: return "exclamationmark.triangle.fill"
            case .held: return "pause.circle.fill"
            case .aborted: return "stop.circle.fill"
            }
        }
        
        var isActive: Bool {
            self == .pending || self == .processing || self == .held
        }
        
        init(ippState: Int32) {
            switch ippState {
            case 3: self = .pending
            case 4: self = .held
            case 5: self = .processing
            case 6: self = .processing
            case 7: self = .cancelled
            case 8: self = .aborted
            case 9: self = .completed
            default: self = .pending
            }
        }
    }
    
    static func create(
        printerName: String,
        documentName: String,
        documentData: Data,
        mimeType: String,
        settings: PrintSettings
    ) -> PrintJob {
        PrintJob(
            id: UUID(),
            jobId: nil,
            printerName: printerName,
            documentName: documentName,
            documentData: documentData,
            documentMimeType: mimeType,
            settings: settings,
            status: .pending,
            statusMessage: nil,
            submittedAt: Date(),
            completedAt: nil,
            pageCount: nil
        )
    }
}
