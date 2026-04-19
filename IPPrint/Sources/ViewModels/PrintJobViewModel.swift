import Foundation
import SwiftUI
import PDFKit

@MainActor
class PrintJobViewModel: ObservableObject {
    @Published var currentJob: PrintJob?
    @Published var jobHistory: [PrintJob] = []
    @Published var settings = PrintSettings()
    @Published var isPrinting = false
    @Published var printProgress: String = ""
    @Published var error: String?
    @Published var showError = false
    @Published var showSuccess = false
    @Published var selectedDocumentData: Data?
    @Published var selectedDocumentName: String?
    @Published var selectedDocumentMimeType: String?
    @Published var documentPageCount: Int?
    @Published var documentThumbnail: UIImage?
    
    private let ippService = IPPService.shared
    
    // MARK: - Document Loading
    
    func loadDocument(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        
        guard let data = try? Data(contentsOf: url) else {
            error = "Failed to read document"
            showError = true
            return
        }
        
        let ext = url.pathExtension.lowercased()
        let mimeType: String
        
        switch ext {
        case "pdf": mimeType = "application/pdf"
        case "jpg", "jpeg": mimeType = "image/jpeg"
        case "png": mimeType = "image/png"
        case "gif": mimeType = "image/gif"
        case "tiff", "tif": mimeType = "image/tiff"
        case "bmp": mimeType = "image/bmp"
        case "txt": mimeType = "text/plain"
        case "html", "htm": mimeType = "text/html"
        default: mimeType = "application/octet-stream"
        }
        
        selectedDocumentData = data
        selectedDocumentName = url.lastPathComponent
        selectedDocumentMimeType = mimeType
        
        // Generate thumbnail and page count
        if mimeType == "application/pdf" {
            if let pdfDoc = PDFDocument(data: data) {
                documentPageCount = pdfDoc.pageCount
                if let page = pdfDoc.page(at: 0) {
                    let bounds = page.bounds(for: .mediaBox)
                    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 280))
                    documentThumbnail = renderer.image { ctx in
                        UIColor.white.setFill()
                        ctx.fill(CGRect(origin: .zero, size: CGSize(width: 200, height: 280)))
                        
                        let scale = min(200 / bounds.width, 280 / bounds.height)
                        ctx.cgContext.scaleBy(x: scale, y: scale)
                        page.draw(with: .mediaBox, to: ctx.cgContext)
                    }
                }
            }
        } else if mimeType.starts(with: "image/") {
            documentPageCount = 1
            documentThumbnail = UIImage(data: data)
        }
    }
    
    func loadImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            error = "Failed to process image"
            showError = true
            return
        }
        
        selectedDocumentData = data
        selectedDocumentName = "Photo_\(Date().formatted(.dateTime.year().month().day().hour().minute())).jpg"
        selectedDocumentMimeType = "image/jpeg"
        documentPageCount = 1
        documentThumbnail = image
    }
    
    func clearDocument() {
        selectedDocumentData = nil
        selectedDocumentName = nil
        selectedDocumentMimeType = nil
        documentPageCount = nil
        documentThumbnail = nil
    }
    
    // MARK: - Printing
    
    func printDocument(to printer: Printer) async {
        guard let data = selectedDocumentData,
              let name = selectedDocumentName,
              let mime = selectedDocumentMimeType else {
            error = "No document selected"
            showError = true
            return
        }
        
        isPrinting = true
        printProgress = "Sending to printer..."
        error = nil
        
        var job = PrintJob.create(
            printerName: printer.name,
            documentName: name,
            documentData: data,
            mimeType: mime,
            settings: settings
        )
        
        currentJob = job
        
        do {
            // Validate first
            printProgress = "Validating print job..."
            let isValid = try await ippService.validateJob(
                printer: printer,
                mimeType: mime,
                settings: settings
            )
            
            if !isValid {
                throw IPPService.IPPError.ippError(.clientErrorNotPossible, "Print job validation failed")
            }
            
            // Send the job
            printProgress = "Printing..."
            let jobId = try await ippService.printDocument(
                to: printer,
                documentData: data,
                documentName: name,
                mimeType: mime,
                settings: settings
            )
            
            job.jobId = jobId
            job.status = .processing
            currentJob = job
            
            // Poll for completion
            printProgress = "Job submitted (ID: \(jobId))"
            
            // Wait and check status
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            let statusResponse = try await ippService.getJobAttributes(printer: printer, jobId: jobId)
            if let stateValue = statusResponse.attribute(named: "job-state")?.intValue {
                job.status = PrintJob.JobStatus(ippState: stateValue)
            }
            
            if job.status == .completed || job.status == .processing {
                job.completedAt = Date()
                showSuccess = true
            }
            
            currentJob = job
            jobHistory.insert(job, at: 0)
            
        } catch {
            job.status = .failed
            job.statusMessage = error.localizedDescription
            currentJob = job
            jobHistory.insert(job, at: 0)
            
            self.error = error.localizedDescription
            showError = true
        }
        
        isPrinting = false
        printProgress = ""
    }
    
    // MARK: - Job Management
    
    func cancelJob(_ job: PrintJob, printer: Printer) {
        guard let jobId = job.jobId else { return }
        
        Task {
            do {
                try await ippService.cancelJob(printer: printer, jobId: jobId)
                if let idx = jobHistory.firstIndex(where: { $0.id == job.id }) {
                    jobHistory[idx].status = .cancelled
                }
                if currentJob?.id == job.id {
                    currentJob?.status = .cancelled
                }
            } catch {
                self.error = error.localizedDescription
                showError = true
            }
        }
    }
    
    func clearHistory() {
        jobHistory.removeAll { !$0.status.isActive }
    }
    
    // MARK: - Web Page Printing
    
    func printWebPage(url: URL, printer: Printer) async {
        isPrinting = true
        printProgress = "Rendering web page..."
        
        // Render web page to PDF using WebKit (simplified)
        // In a full implementation, this would use WKWebView to render
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            selectedDocumentData = data
            selectedDocumentName = url.host ?? "webpage"
            selectedDocumentMimeType = "text/html"
            
            await printDocument(to: printer)
        } catch {
            self.error = "Failed to load web page: \(error.localizedDescription)"
            showError = true
            isPrinting = false
        }
    }
}
