import Foundation

// MARK: - IPP Protocol Constants

enum IPPVersion {
    static let major: UInt8 = 2
    static let minor: UInt8 = 0
}

enum IPPOperation: UInt16 {
    // Printer Operations
    case printJob = 0x0002
    case printURI = 0x0003
    case validateJob = 0x0004
    case createJob = 0x0005
    case sendDocument = 0x0006
    case sendURI = 0x0007
    case cancelJob = 0x0008
    case getJobAttributes = 0x0009
    case getJobs = 0x000A
    case getPrinterAttributes = 0x000B
    case holdJob = 0x000C
    case releaseJob = 0x000D
    case restartJob = 0x000E
    case pausePrinter = 0x0010
    case resumePrinter = 0x0011
    case purgeJobs = 0x0012
}

enum IPPStatusCode: UInt16 {
    case successfulOK = 0x0000
    case successfulOKIgnored = 0x0001
    case successfulOKConflicting = 0x0002
    
    case clientErrorBadRequest = 0x0400
    case clientErrorForbidden = 0x0401
    case clientErrorNotAuthenticated = 0x0402
    case clientErrorNotAuthorized = 0x0403
    case clientErrorNotPossible = 0x0404
    case clientErrorTimeout = 0x0405
    case clientErrorNotFound = 0x0406
    case clientErrorGone = 0x0407
    case clientErrorDocumentFormatNotSupported = 0x040A
    case clientErrorAttributes = 0x040B
    
    case serverErrorInternalError = 0x0500
    case serverErrorOperationNotSupported = 0x0501
    case serverErrorServiceUnavailable = 0x0502
    case serverErrorVersionNotSupported = 0x0503
    case serverErrorDeviceError = 0x0504
    case serverErrorTemporaryError = 0x0505
    case serverErrorNotAccepting = 0x0506
    case serverErrorBusy = 0x0507
    
    var isSuccess: Bool { rawValue < 0x0400 }
    
    var localizedDescription: String {
        switch self {
        case .successfulOK: return "Success"
        case .successfulOKIgnored: return "Success (some attributes ignored)"
        case .successfulOKConflicting: return "Success (conflicting attributes)"
        case .clientErrorBadRequest: return "Bad request"
        case .clientErrorForbidden: return "Forbidden"
        case .clientErrorNotAuthenticated: return "Authentication required"
        case .clientErrorNotAuthorized: return "Not authorized"
        case .clientErrorNotPossible: return "Not possible"
        case .clientErrorTimeout: return "Request timeout"
        case .clientErrorNotFound: return "Not found"
        case .clientErrorGone: return "Gone"
        case .clientErrorDocumentFormatNotSupported: return "Document format not supported"
        case .clientErrorAttributes: return "Attribute error"
        case .serverErrorInternalError: return "Server internal error"
        case .serverErrorOperationNotSupported: return "Operation not supported"
        case .serverErrorServiceUnavailable: return "Service unavailable"
        case .serverErrorVersionNotSupported: return "Version not supported"
        case .serverErrorDeviceError: return "Device error"
        case .serverErrorTemporaryError: return "Temporary error"
        case .serverErrorNotAccepting: return "Not accepting jobs"
        case .serverErrorBusy: return "Busy"
        }
    }
}

enum IPPTag: UInt8 {
    // Delimiter tags
    case operationAttributes = 0x01
    case jobAttributes = 0x02
    case endOfAttributes = 0x03
    case printerAttributes = 0x04
    case unsupportedAttributes = 0x05
    
    // Value tags
    case unsupported = 0x10
    case unknown = 0x12
    case noValue = 0x13
    case integer = 0x21
    case boolean = 0x22
    case enumValue = 0x23
    case octetString = 0x30
    case dateTime = 0x31
    case resolution = 0x32
    case rangeOfInteger = 0x33
    case begCollection = 0x34
    case textWithLanguage = 0x35
    case nameWithLanguage = 0x36
    case endCollection = 0x37
    case textWithoutLanguage = 0x41
    case nameWithoutLanguage = 0x42
    case keyword = 0x44
    case uri = 0x45
    case uriScheme = 0x46
    case charset = 0x47
    case naturalLanguage = 0x48
    case mimeMediaType = 0x49
    case memberAttrName = 0x4A
}

// MARK: - IPP Attribute

struct IPPAttribute {
    let tag: IPPTag
    let name: String
    let values: [IPPValue]
    
    var firstValue: IPPValue? { values.first }
    var stringValue: String? { firstValue?.stringValue }
    var intValue: Int32? { firstValue?.intValue }
    var boolValue: Bool? { firstValue?.boolValue }
}

enum IPPValue {
    case integer(Int32)
    case boolean(Bool)
    case enumValue(Int32)
    case string(String)
    case uri(String)
    case keyword(String)
    case charset(String)
    case naturalLanguage(String)
    case mimeType(String)
    case dateTime(Data)
    case resolution(xRes: Int32, yRes: Int32, units: UInt8)
    case rangeOfInteger(lower: Int32, upper: Int32)
    case octetString(Data)
    case noValue
    case unknown(Data)
    
    var stringValue: String? {
        switch self {
        case .string(let s), .uri(let s), .keyword(let s),
             .charset(let s), .naturalLanguage(let s), .mimeType(let s):
            return s
        case .integer(let i), .enumValue(let i):
            return "\(i)"
        case .boolean(let b):
            return b ? "true" : "false"
        default:
            return nil
        }
    }
    
    var intValue: Int32? {
        switch self {
        case .integer(let i), .enumValue(let i): return i
        case .boolean(let b): return b ? 1 : 0
        default: return nil
        }
    }
    
    var boolValue: Bool? {
        switch self {
        case .boolean(let b): return b
        case .integer(let i): return i != 0
        default: return nil
        }
    }
}

// MARK: - IPP Request / Response

struct IPPRequest {
    let operation: IPPOperation
    var requestId: Int32 = 1
    var operationAttributes: [IPPAttribute] = []
    var jobAttributes: [IPPAttribute] = []
    var documentData: Data?
    
    mutating func addOperationAttribute(_ name: String, tag: IPPTag, value: IPPValue) {
        operationAttributes.append(IPPAttribute(tag: tag, name: name, values: [value]))
    }
    
    mutating func addJobAttribute(_ name: String, tag: IPPTag, value: IPPValue) {
        jobAttributes.append(IPPAttribute(tag: tag, name: name, values: [value]))
    }
}

struct IPPResponse {
    let statusCode: IPPStatusCode
    let requestId: Int32
    var operationAttributes: [IPPAttribute] = []
    var printerAttributes: [IPPAttribute] = []
    var jobAttributes: [IPPAttribute] = []
    var unsupportedAttributes: [IPPAttribute] = []
    
    func attribute(named name: String) -> IPPAttribute? {
        return printerAttributes.first { $0.name == name }
            ?? operationAttributes.first { $0.name == name }
            ?? jobAttributes.first { $0.name == name }
    }
    
    func allValues(named name: String) -> [IPPValue] {
        let attrs = printerAttributes.filter { $0.name == name }
            + operationAttributes.filter { $0.name == name }
            + jobAttributes.filter { $0.name == name }
        return attrs.flatMap { $0.values }
    }
}

// MARK: - Print Settings

struct PrintSettings: Codable, Equatable {
    var copies: Int = 1
    var colorMode: ColorMode = .color
    var paperSize: PaperSize = .a4
    var orientation: Orientation = .portrait
    var quality: PrintQuality = .normal
    var sides: Sides = .oneSided
    var pageRange: PageRange = .all
    var fitToPage: Bool = true
    var mediaType: MediaType = .plain
    
    enum ColorMode: String, Codable, CaseIterable, Identifiable {
        case color = "color"
        case monochrome = "monochrome"
        case auto = "auto"
        
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .color: return "Color"
            case .monochrome: return "Black & White"
            case .auto: return "Auto"
            }
        }
        var ippValue: String { rawValue }
    }
    
    enum PaperSize: String, Codable, CaseIterable, Identifiable {
        case a4 = "iso_a4_210x297mm"
        case a3 = "iso_a3_297x420mm"
        case a5 = "iso_a5_148x210mm"
        case letter = "na_letter_8.5x11in"
        case legal = "na_legal_8.5x14in"
        case photo4x6 = "na_index-4x6_4x6in"
        case photo5x7 = "na_5x7_5x7in"
        
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .a4: return "A4"
            case .a3: return "A3"
            case .a5: return "A5"
            case .letter: return "US Letter"
            case .legal: return "US Legal"
            case .photo4x6: return "4×6 Photo"
            case .photo5x7: return "5×7 Photo"
            }
        }
    }
    
    enum Orientation: String, Codable, CaseIterable, Identifiable {
        case portrait = "3"
        case landscape = "4"
        case reverseLandscape = "5"
        case reversePortrait = "6"
        
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .portrait: return "Portrait"
            case .landscape: return "Landscape"
            case .reverseLandscape: return "Reverse Landscape"
            case .reversePortrait: return "Reverse Portrait"
            }
        }
        var ippValue: Int32 { Int32(rawValue) ?? 3 }
    }
    
    enum PrintQuality: String, Codable, CaseIterable, Identifiable {
        case draft = "3"
        case normal = "4"
        case high = "5"
        
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .draft: return "Draft"
            case .normal: return "Normal"
            case .high: return "High Quality"
            }
        }
        var ippValue: Int32 { Int32(rawValue) ?? 4 }
    }
    
    enum Sides: String, Codable, CaseIterable, Identifiable {
        case oneSided = "one-sided"
        case twoSidedLong = "two-sided-long-edge"
        case twoSidedShort = "two-sided-short-edge"
        
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .oneSided: return "Single Sided"
            case .twoSidedLong: return "Double Sided (Long Edge)"
            case .twoSidedShort: return "Double Sided (Short Edge)"
            }
        }
    }
    
    enum PageRange: Codable, Equatable {
        case all
        case range(from: Int, to: Int)
        case custom(String)
        
        var displayName: String {
            switch self {
            case .all: return "All Pages"
            case .range(let from, let to): return "Pages \(from)-\(to)"
            case .custom(let s): return s
            }
        }
    }
    
    enum MediaType: String, Codable, CaseIterable, Identifiable {
        case plain = "stationery"
        case photo = "photographic"
        case photoGlossy = "photographic-glossy"
        case photoMatte = "photographic-matte"
        case envelope = "envelope"
        case transparency = "transparency"
        case labels = "labels"
        case cardstock = "cardstock"
        
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .plain: return "Plain Paper"
            case .photo: return "Photo Paper"
            case .photoGlossy: return "Glossy Photo"
            case .photoMatte: return "Matte Photo"
            case .envelope: return "Envelope"
            case .transparency: return "Transparency"
            case .labels: return "Labels"
            case .cardstock: return "Cardstock"
            }
        }
    }
}
