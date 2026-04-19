import Foundation

class IPPDecoder {
    
    enum DecoderError: Error, LocalizedError {
        case invalidData
        case truncatedData
        case unknownVersion(UInt8, UInt8)
        
        var errorDescription: String? {
            switch self {
            case .invalidData: return "Invalid IPP response data"
            case .truncatedData: return "Truncated IPP response"
            case .unknownVersion(let maj, let min): return "Unknown IPP version \(maj).\(min)"
            }
        }
    }
    
    func decode(_ data: Data) throws -> IPPResponse {
        guard data.count >= 8 else { throw DecoderError.truncatedData }
        
        var offset = 0
        
        // Version
        let versionMajor = data[offset]; offset += 1
        let versionMinor = data[offset]; offset += 1
        
        guard versionMajor >= 1 && versionMajor <= 2 else {
            throw DecoderError.unknownVersion(versionMajor, versionMinor)
        }
        
        // Status code
        let statusRaw = readUInt16(data, offset: &offset)
        let statusCode = IPPStatusCode(rawValue: statusRaw) ?? .clientErrorBadRequest
        
        // Request ID
        let requestId = readInt32(data, offset: &offset)
        
        var response = IPPResponse(statusCode: statusCode, requestId: requestId)
        
        // Parse attribute groups
        var currentGroup: IPPTag?
        
        while offset < data.count {
            let tag = data[offset]; offset += 1
            
            // Check for delimiter tags
            if tag == IPPTag.endOfAttributes.rawValue {
                break
            }
            
            if tag <= 0x0F {
                // Delimiter tag
                currentGroup = IPPTag(rawValue: tag)
                continue
            }
            
            // Value tag - parse attribute
            guard offset + 2 <= data.count else { break }
            let nameLength = Int(readUInt16(data, offset: &offset))
            
            var name = ""
            if nameLength > 0 {
                guard offset + nameLength <= data.count else { break }
                name = String(data: data[offset..<(offset + nameLength)], encoding: .utf8) ?? ""
                offset += nameLength
            }
            
            guard offset + 2 <= data.count else { break }
            let valueLength = Int(readUInt16(data, offset: &offset))
            
            guard offset + valueLength <= data.count else { break }
            let valueData = data[offset..<(offset + valueLength)]
            offset += valueLength
            
            let valueTag = IPPTag(rawValue: tag)
            let value = parseValue(tag: valueTag, data: Data(valueData))
            
            if name.isEmpty {
                // Additional value for previous attribute
                appendToLastAttribute(in: &response, group: currentGroup, value: value)
            } else {
                let attr = IPPAttribute(tag: valueTag ?? .unknown, name: name, values: [value])
                addAttribute(to: &response, group: currentGroup, attribute: attr)
            }
        }
        
        return response
    }
    
    private func parseValue(tag: IPPTag?, data: Data) -> IPPValue {
        guard let tag = tag else { return .unknown(data) }
        
        switch tag {
        case .integer:
            guard data.count >= 4 else { return .integer(0) }
            var offset = 0
            return .integer(readInt32(Array(data), offset: &offset))
            
        case .boolean:
            return .boolean(data.first != 0)
            
        case .enumValue:
            guard data.count >= 4 else { return .enumValue(0) }
            var offset = 0
            return .enumValue(readInt32(Array(data), offset: &offset))
            
        case .textWithoutLanguage, .nameWithoutLanguage:
            return .string(String(data: data, encoding: .utf8) ?? "")
            
        case .keyword:
            return .keyword(String(data: data, encoding: .utf8) ?? "")
            
        case .uri:
            return .uri(String(data: data, encoding: .utf8) ?? "")
            
        case .charset:
            return .charset(String(data: data, encoding: .utf8) ?? "")
            
        case .naturalLanguage:
            return .naturalLanguage(String(data: data, encoding: .utf8) ?? "")
            
        case .mimeMediaType:
            return .mimeType(String(data: data, encoding: .utf8) ?? "")
            
        case .dateTime:
            return .dateTime(data)
            
        case .resolution:
            guard data.count >= 9 else { return .noValue }
            var offset = 0
            let x = readInt32(Array(data), offset: &offset)
            let y = readInt32(Array(data), offset: &offset)
            let u = data[8]
            return .resolution(xRes: x, yRes: y, units: u)
            
        case .rangeOfInteger:
            guard data.count >= 8 else { return .noValue }
            var offset = 0
            let lower = readInt32(Array(data), offset: &offset)
            let upper = readInt32(Array(data), offset: &offset)
            return .rangeOfInteger(lower: lower, upper: upper)
            
        case .octetString:
            return .octetString(data)
            
        case .noValue:
            return .noValue
            
        default:
            return .unknown(data)
        }
    }
    
    private func addAttribute(to response: inout IPPResponse, group: IPPTag?, attribute: IPPAttribute) {
        switch group {
        case .operationAttributes:
            response.operationAttributes.append(attribute)
        case .printerAttributes:
            response.printerAttributes.append(attribute)
        case .jobAttributes:
            response.jobAttributes.append(attribute)
        case .unsupportedAttributes:
            response.unsupportedAttributes.append(attribute)
        default:
            response.operationAttributes.append(attribute)
        }
    }
    
    private func appendToLastAttribute(in response: inout IPPResponse, group: IPPTag?, value: IPPValue) {
        func appendValue(to attrs: inout [IPPAttribute]) {
            guard !attrs.isEmpty else { return }
            var last = attrs.removeLast()
            var values = last.values
            values.append(value)
            last = IPPAttribute(tag: last.tag, name: last.name, values: values)
            attrs.append(last)
        }
        
        switch group {
        case .operationAttributes: appendValue(to: &response.operationAttributes)
        case .printerAttributes: appendValue(to: &response.printerAttributes)
        case .jobAttributes: appendValue(to: &response.jobAttributes)
        default: appendValue(to: &response.operationAttributes)
        }
    }
    
    // Data-based read
    private func readUInt16(_ data: Data, offset: inout Int) -> UInt16 {
        let value = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
        offset += 2
        return value
    }
    
    private func readInt32(_ data: Data, offset: inout Int) -> Int32 {
        let value = Int32(data[offset]) << 24 | Int32(data[offset + 1]) << 16 |
                    Int32(data[offset + 2]) << 8 | Int32(data[offset + 3])
        offset += 4
        return value
    }
    
    // Array-based read
    private func readInt32(_ data: [UInt8], offset: inout Int) -> Int32 {
        let value = Int32(data[offset]) << 24 | Int32(data[offset + 1]) << 16 |
                    Int32(data[offset + 2]) << 8 | Int32(data[offset + 3])
        offset += 4
        return value
    }
}
