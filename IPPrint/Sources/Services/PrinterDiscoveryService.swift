import Foundation
import Network

class PrinterDiscoveryService: ObservableObject {
    @Published var discoveredPrinters: [Printer] = []
    @Published var isSearching = false
    @Published var error: String?
    
    private var browser: NWBrowser?
    private var ippsBrowser: NWBrowser?
    
    func startDiscovery() {
        isSearching = true
        error = nil
        discoveredPrinters.removeAll()
        
        // Browse for IPP printers
        let ippParams = NWBrowser.Descriptor.bonjour(type: "_ipp._tcp", domain: nil)
        browser = NWBrowser(for: ippParams, using: .tcp)
        
        browser?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isSearching = true
                case .failed(let err):
                    self?.error = "Discovery failed: \(err.localizedDescription)"
                    self?.isSearching = false
                case .cancelled:
                    self?.isSearching = false
                default:
                    break
                }
            }
        }
        
        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            self?.handleResults(results)
        }
        
        browser?.start(queue: .main)
        
        // Also browse for IPPS (secure)
        let ippsParams = NWBrowser.Descriptor.bonjour(type: "_ipps._tcp", domain: nil)
        ippsBrowser = NWBrowser(for: ippsParams, using: .tcp)
        
        ippsBrowser?.browseResultsChangedHandler = { [weak self] results, changes in
            self?.handleSecureResults(results)
        }
        
        ippsBrowser?.start(queue: .main)
        
        // Auto-stop after 15 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.stopDiscovery()
        }
    }
    
    func stopDiscovery() {
        browser?.cancel()
        ippsBrowser?.cancel()
        browser = nil
        ippsBrowser = nil
        isSearching = false
    }
    
    private func handleResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            if case .service(let name, let type, let domain, _) = result.endpoint {
                resolvePrinter(name: name, type: type, domain: domain, useSSL: false)
            }
        }
    }
    
    private func handleSecureResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            if case .service(let name, let type, let domain, _) = result.endpoint {
                resolvePrinter(name: name, type: type, domain: domain, useSSL: true)
            }
        }
    }
    
    private func resolvePrinter(name: String, type: String, domain: String, useSSL: Bool) {
        // Use NWConnection to resolve the service
        let endpoint = NWEndpoint.service(name: name, type: type, domain: domain, interface: nil)
        let connection = NWConnection(to: endpoint, using: .tcp)
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                   case .hostPort(let host, let port) = innerEndpoint {
                    let hostname: String
                    switch host {
                    case .ipv4(let addr):
                        hostname = "\(addr)"
                    case .ipv6(let addr):
                        hostname = "\(addr)"
                    case .name(let name, _):
                        hostname = name
                    @unknown default:
                        hostname = name
                    }
                    
                    let printer = Printer(
                        id: UUID(),
                        name: name,
                        hostname: hostname,
                        port: Int(port.rawValue),
                        resourcePath: "/ipp/print",
                        useSSL: useSSL,
                        makeAndModel: nil,
                        location: nil,
                        state: .unknown,
                        stateMessage: nil,
                        supportsColor: true,
                        supportsDuplex: false,
                        supportedMediaSizes: [],
                        supportedDocumentFormats: [],
                        maxCopies: 99,
                        supportsPageRanges: true,
                        firmwareVersion: nil,
                        serialNumber: nil,
                        isManuallyAdded: false,
                        lastSeen: Date(),
                        isFavorite: false
                    )
                    
                    DispatchQueue.main.async {
                        // Avoid duplicates
                        if !(self?.discoveredPrinters.contains(where: {
                            $0.hostname == printer.hostname && $0.port == printer.port
                        }) ?? true) {
                            self?.discoveredPrinters.append(printer)
                        }
                    }
                    
                    // Fetch printer attributes
                    Task {
                        if let self = self {
                            do {
                                let updated = try await IPPService.shared.getPrinterAttributes(printer: printer)
                                await MainActor.run {
                                    if let idx = self.discoveredPrinters.firstIndex(where: { $0.id == printer.id }) {
                                        self.discoveredPrinters[idx] = updated
                                    }
                                }
                            } catch {
                                // Keep the basic info even if attribute fetch fails
                            }
                        }
                    }
                }
                connection.cancel()
                
            case .failed:
                connection.cancel()
            default:
                break
            }
        }
        
        connection.start(queue: .global(qos: .userInitiated))
    }
}
