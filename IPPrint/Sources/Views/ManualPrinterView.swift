import SwiftUI

struct ManualPrinterView: View {
    let onAdd: (String, String, Int, String, Bool) -> Void
    
    @State private var name = ""
    @State private var hostname = ""
    @State private var port = "631"
    @State private var path = "/ipp/print"
    @State private var useSSL = false
    @State private var isTesting = false
    @State private var testResult: TestResult?
    
    enum TestResult {
        case success(String)
        case failure(String)
    }
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "printer.dotmatrix.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.accent)
                    
                    Text("Add your printer manually by entering its IP address and connection details.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            Section("Printer Details") {
                TextField("Printer Name", text: $name)
                    .textContentType(.name)
                
                TextField("IP Address or Hostname", text: $hostname)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            
            Section("Connection") {
                HStack {
                    Text("Port")
                    Spacer()
                    TextField("631", text: $port)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                
                TextField("Resource Path", text: $path)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                Toggle("Use SSL (IPPS)", isOn: $useSSL)
                    .onChange(of: useSSL) { _, newValue in
                        if newValue && port == "631" {
                            port = "443"
                        } else if !newValue && port == "443" {
                            port = "631"
                        }
                    }
            }
            
            Section("Common Paths") {
                Button("/ipp/print") { path = "/ipp/print" }
                    .foregroundStyle(path == "/ipp/print" ? .accent : .primary)
                Button("/ipp/printer") { path = "/ipp/printer" }
                    .foregroundStyle(path == "/ipp/printer" ? .accent : .primary)
                Button("/printers/default") { path = "/printers/default" }
                    .foregroundStyle(path == "/printers/default" ? .accent : .primary)
            }
            
            Section {
                // Test connection
                Button {
                    testConnection()
                } label: {
                    HStack {
                        Label("Test Connection", systemImage: "antenna.radiowaves.left.and.right")
                        Spacer()
                        if isTesting {
                            ProgressView()
                        }
                    }
                }
                .disabled(hostname.isEmpty || isTesting)
                
                if let result = testResult {
                    switch result {
                    case .success(let msg):
                        Label(msg, systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    case .failure(let msg):
                        Label(msg, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
            }
            
            Section {
                Button {
                    let printerName = name.isEmpty ? hostname : name
                    let portNum = Int(port) ?? 631
                    onAdd(printerName, hostname, portNum, path, useSSL)
                } label: {
                    HStack {
                        Spacer()
                        Label("Add Printer", systemImage: "plus.circle.fill")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(hostname.isEmpty)
            }
        }
    }
    
    private func testConnection() {
        isTesting = true
        testResult = nil
        
        let printerName = name.isEmpty ? hostname : name
        let portNum = Int(port) ?? 631
        let printer = Printer.manual(name: printerName, hostname: hostname, port: portNum, path: path, ssl: useSSL)
        
        Task {
            do {
                let updated = try await IPPService.shared.getPrinterAttributes(printer: printer)
                await MainActor.run {
                    testResult = .success("Connected! \(updated.makeAndModel ?? updated.name)")
                    if name.isEmpty, let model = updated.makeAndModel {
                        name = model
                    }
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = .failure(error.localizedDescription)
                    isTesting = false
                }
            }
        }
    }
}
