import Foundation

class IPPEncoder {
    
    func encode(_ request: IPPRequest) -> Data {
        var data = Data()
        
        // Version
        data.append(IPPVersion.major)
        data.append(IPPVersion.minor)
        
        // Operation ID
        appendUInt16(&data, request.operation.rawValue)
        
        // Request ID
        appendInt32(&data, request.requestId)
        
        // Operation attributes
        data.append(IPPTag.operationAttributes.rawValue)
        
        // Always include charset and language first
        encodeAttribute(&data, name: "attributes-charset", tag: .charset, value: .charset("utf-8"))
        encodeAttribute(&data, name: "attributes-natural-language", tag: .naturalLanguage, value: .naturalLanguage("en"))
        
        for attr in request.operationAttributes {
            for value in attr.values {
                encodeAttribute(&data, name: attr.name, tag: attr.tag, value: value)
            }
        }
        
        // Job attributes
        if !request.jobAttributes.isEmpty {
            data.append(IPPTag.jobAttributes.rawValue)
            for attr in request.jobAttributes {
                for value in attr.values {
                    encodeAttribute(&data, name: attr.name, tag: attr.tag, value: value)
                }
            }
        }
        
        // End of attributes
        data.append(IPPTag.endOfAttributes.rawValue)
        
        // Document data
        if let docData = request.documentData {
            data.append(docData)
        }
        
        return data
    }
    
    private func encodeAttribute(_ data: inout Data, name: String, tag: IPPTag, value: IPPValue) {
        data.append(tag.rawValue)
        
        // Name
        let nameData = name.data(using: .utf8) ?? Data()
        appendUInt16(&data, UInt16(nameData.count))
        data.append(nameData)
        
        // Value
        switch value {
        case .integer(let v):
            appendUInt16(&data, 4)
            appendInt32(&data, v)
            
        case .boolean(let v):
            appendUInt16(&data, 1)
            data.append(v ? 1 : 0)
            
        case .enumValue(let v):
            appendUInt16(&data, 4)
            appendInt32(&data, v)
            
        case .string(let s), .uri(let s), .keyword(let s),
             .charset(let s), .naturalLanguage(let s), .mimeType(let s):
            let strData = s.data(using: .utf8) ?? Data()
            appendUInt16(&data, UInt16(strData.count))
            data.append(strData)
            
        case .dateTime(let d):
            appendUInt16(&data, UInt16(d.count))
            data.append(d)
            
        case .resolution(let xRes, let yRes, let units):
            appendUInt16(&data, 9)
            appendInt32(&data, xRes)
            appendInt32(&data, yRes)
            data.append(units)
            
        case .rangeOfInteger(let lower, let upper):
            appendUInt16(&data, 8)
            appendInt32(&data, lower)
            appendInt32(&data, upper)
            
        case .octetString(let d):
            appendUInt16(&data, UInt16(d.count))
            data.append(d)
            
        case .noValue, .unknown:
            appendUInt16(&data, 0)
        }
    }
    
    private func appendUInt16(_ data: inout Data, _ value: UInt16) {
        var bigEndian = value.bigEndian
        data.append(Data(bytes: &bigEndian, count: 2))
    }
    
    private func appendInt32(_ data: inout Data, _ value: Int32) {
        var bigEndian = value.bigEndian
        data.append(Data(bytes: &bigEndian, count: 4))
    }
}
