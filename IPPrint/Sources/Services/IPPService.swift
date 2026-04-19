import Foundation

class IPPService {
    static let shared = IPPService()
    
    private let encoder = IPPEncoder()
    private let decoder = IPPDecoder()
    private var requestCounter: Int32 = 1
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config)
    }()
    
    enum IPPError: Error, LocalizedError {
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case ippError(IPPStatusCode, String?)
        case documentConversionFailed
        case noData
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid printer URL"
            case .networkError(let e): return "Network error: \(e.localizedDescription)"
            case .invalidResponse: return "Invalid response from printer"
            case .ippError(let code, let msg): return msg ?? code.localizedDescription
            case .documentConversionFailed: return "Failed to convert document for printing"
            case .noData: return "No data received from printer"
            }
        }
    }
    
    // MARK: - Get Printer Attributes
    
    func getPrinterAttributes(printer: Printer) async throws -> Printer {
        guard let url = printer.httpURL else { throw IPPError.invalidURL }
        
        var request = IPPRequest(operation: .getPrinterAttributes, requestId: nextRequestId())
        request.addOperationAttribute("printer-uri", tag: .uri, value: .uri(printer.uri))
        request.addOperationAttribute("requested-attributes", tag: .keyword, value: .keyword("all"))
        
        let response = try await sendRequest(request, to: url)
        
        guard response.statusCode.isSuccess else {
            throw IPPError.ippError(response.statusCode, response.attribute(named: "status-message")?.stringValue)
        }
        
        return updatePrinter(printer, from: response)
    }
    
    // MARK: - Print Job
    
    func printDocument(
        to printer: Printer,
        documentData: Data,
        documentName: String,
        mimeType: String,
        settings: PrintSettings
    ) async throws -> Int32 {
        guard let url = printer.httpURL else { throw IPPError.invalidURL }
        
        var request = IPPRequest(operation: .printJob, requestId: nextRequestId())
        request.addOperationAttribute("printer-uri", tag: .uri, value: .uri(printer.uri))
        request.addOperationAttribute("requesting-user-name", tag: .nameWithoutLanguage, value: .string("IPPrint User"))
        request.addOperationAttribute("job-name", tag: .nameWithoutLanguage, value: .string(documentName))
        request.addOperationAttribute("document-format", tag: .mimeMediaType, value: .mimeType(mimeType))
        
        // Job attributes from settings
        request.addJobAttribute("copies", tag: .integer, value: .integer(Int32(settings.copies)))
        request.addJobAttribute("print-quality", tag: .enumValue, value: .enumValue(settings.quality.ippValue))
        request.addJobAttribute("orientation-requested", tag: .enumValue, value: .enumValue(settings.orientation.ippValue))
        request.addJobAttribute("sides", tag: .keyword, value: .keyword(settings.sides.rawValue))
        request.addJobAttribute("media", tag: .keyword, value: .keyword(settings.paperSize.rawValue))
        request.addJobAttribute("print-color-mode", tag: .keyword, value: .keyword(settings.colorMode.ippValue))
        
        if settings.fitToPage {
            request.addJobAttribute("print-scaling", tag: .keyword, value: .keyword("fit"))
        }
        
        if settings.mediaType != .plain {
            request.addJobAttribute("media-type", tag: .keyword, value: .keyword(settings.mediaType.rawValue))
        }
        
        // Page ranges
        if case .range(let from, let to) = settings.pageRange {
            request.addJobAttribute("page-ranges", tag: .rangeOfInteger,
                                    value: .rangeOfInteger(lower: Int32(from), upper: Int32(to)))
        }
        
        request.documentData = documentData
        
        let response = try await sendRequest(request, to: url)
        
        guard response.statusCode.isSuccess else {
            throw IPPError.ippError(response.statusCode, response.attribute(named: "status-message")?.stringValue)
        }
        
        let jobId = response.attribute(named: "job-id")?.intValue ?? 0
        return jobId
    }
    
    // MARK: - Validate Job
    
    func validateJob(
        printer: Printer,
        mimeType: String,
        settings: PrintSettings
    ) async throws -> Bool {
        guard let url = printer.httpURL else { throw IPPError.invalidURL }
        
        var request = IPPRequest(operation: .validateJob, requestId: nextRequestId())
        request.addOperationAttribute("printer-uri", tag: .uri, value: .uri(printer.uri))
        request.addOperationAttribute("document-format", tag: .mimeMediaType, value: .mimeType(mimeType))
        request.addJobAttribute("copies", tag: .integer, value: .integer(Int32(settings.copies)))
        request.addJobAttribute("sides", tag: .keyword, value: .keyword(settings.sides.rawValue))
        
        let response = try await sendRequest(request, to: url)
        return response.statusCode.isSuccess
    }
    
    // MARK: - Get Jobs
    
    func getJobs(printer: Printer, whichJobs: String = "not-completed") async throws -> [IPPResponse] {
        guard let url = printer.httpURL else { throw IPPError.invalidURL }
        
        var request = IPPRequest(operation: .getJobs, requestId: nextRequestId())
        request.addOperationAttribute("printer-uri", tag: .uri, value: .uri(printer.uri))
        request.addOperationAttribute("which-jobs", tag: .keyword, value: .keyword(whichJobs))
        request.addOperationAttribute("requested-attributes", tag: .keyword, value: .keyword("all"))
        
        let response = try await sendRequest(request, to: url)
        
        guard response.statusCode.isSuccess else {
            throw IPPError.ippError(response.statusCode, nil)
        }
        
        return [response]
    }
    
    // MARK: - Cancel Job
    
    func cancelJob(printer: Printer, jobId: Int32) async throws {
        guard let url = printer.httpURL else { throw IPPError.invalidURL }
        
        var request = IPPRequest(operation: .cancelJob, requestId: nextRequestId())
        request.addOperationAttribute("printer-uri", tag: .uri, value: .uri(printer.uri))
        request.addOperationAttribute("job-id", tag: .integer, value: .integer(jobId))
        request.addOperationAttribute("requesting-user-name", tag: .nameWithoutLanguage, value: .string("IPPrint User"))
        
        let response = try await sendRequest(request, to: url)
        
        guard response.statusCode.isSuccess else {
            throw IPPError.ippError(response.statusCode, nil)
        }
    }
    
    // MARK: - Get Job Attributes
    
    func getJobAttributes(printer: Printer, jobId: Int32) async throws -> IPPResponse {
        guard let url = printer.httpURL else { throw IPPError.invalidURL }
        
        var request = IPPRequest(operation: .getJobAttributes, requestId: nextRequestId())
        request.addOperationAttribute("printer-uri", tag: .uri, value: .uri(printer.uri))
        request.addOperationAttribute("job-id", tag: .integer, value: .integer(jobId))
        request.addOperationAttribute("requested-attributes", tag: .keyword, value: .keyword("all"))
        
        let response = try await sendRequest(request, to: url)
        return response
    }
    
    // MARK: - Network
    
    private func sendRequest(_ ippRequest: IPPRequest, to url: URL) async throws -> IPPResponse {
        let body = encoder.encode(ippRequest)
        
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("application/ipp", forHTTPHeaderField: "Content-Type")
        httpRequest.setValue("application/ipp", forHTTPHeaderField: "Accept")
        httpRequest.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        httpRequest.httpBody = body
        
        do {
            let (data, httpResponse) = try await session.data(for: httpRequest)
            
            guard let http = httpResponse as? HTTPURLResponse else {
                throw IPPError.invalidResponse
            }
            
            guard http.statusCode == 200 else {
                throw IPPError.invalidResponse
            }
            
            guard !data.isEmpty else {
                throw IPPError.noData
            }
            
            return try decoder.decode(data)
        } catch let error as IPPError {
            throw error
        } catch let error as IPPDecoder.DecoderError {
            throw IPPError.invalidResponse
        } catch {
            throw IPPError.networkError(error)
        }
    }
    
    // MARK: - Helpers
    
    private func nextRequestId() -> Int32 {
        requestCounter += 1
        return requestCounter
    }
    
    private func updatePrinter(_ printer: Printer, from response: IPPResponse) -> Printer {
        var updated = printer
        
        if let name = response.attribute(named: "printer-name")?.stringValue {
            updated.name = name
        }
        if let makeModel = response.attribute(named: "printer-make-and-model")?.stringValue {
            updated.makeAndModel = makeModel
        }
        if let location = response.attribute(named: "printer-location")?.stringValue {
            updated.location = location
        }
        if let state = response.attribute(named: "printer-state")?.intValue {
            updated.state = Printer.PrinterState(ippState: state)
        }
        if let stateMsg = response.attribute(named: "printer-state-message")?.stringValue {
            updated.stateMessage = stateMsg
        }
        if let firmware = response.attribute(named: "printer-firmware-string-version")?.stringValue {
            updated.firmwareVersion = firmware
        }
        if let serial = response.attribute(named: "printer-device-id")?.stringValue {
            updated.serialNumber = serial
        }
        
        // Color support
        let colorModes = response.allValues(named: "print-color-mode-supported").compactMap { $0.stringValue }
        updated.supportsColor = colorModes.contains("color")
        
        // Duplex support
        let sides = response.allValues(named: "sides-supported").compactMap { $0.stringValue }
        updated.supportsDuplex = sides.contains("two-sided-long-edge") || sides.contains("two-sided-short-edge")
        
        // Media sizes
        let media = response.allValues(named: "media-supported").compactMap { $0.stringValue }
        if !media.isEmpty { updated.supportedMediaSizes = media }
        
        // Document formats
        let formats = response.allValues(named: "document-format-supported").compactMap { $0.stringValue }
        if !formats.isEmpty { updated.supportedDocumentFormats = formats }
        
        // Max copies
        if let maxCopies = response.attribute(named: "copies-supported") {
            if case .rangeOfInteger(_, let upper) = maxCopies.firstValue {
                updated.maxCopies = Int(upper)
            }
        }
        
        // Page ranges
        updated.supportsPageRanges = response.attribute(named: "page-ranges-supported")?.boolValue ?? false
        
        updated.lastSeen = Date()
        return updated
    }
}
