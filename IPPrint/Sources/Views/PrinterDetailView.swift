import SwiftUI

struct PrinterDetailView: View {
    let printer: Printer
    @EnvironmentObject var printerVM: PrinterViewModel
    @State private var isRefreshing = false
    
    var body: some View {
        List {
            // Status section
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(stateColor.opacity(0.12))
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: "printer.fill")
                            .font(.title)
                            .foregroundStyle(stateColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(printer.name)
                            .font(.title3.weight(.semibold))
                        
                        HStack(spacing: 6) {
                            Image(systemName: printer.state.iconName)
                                .foregroundStyle(stateColor)
                            Text(printer.state.displayName)
                                .foregroundStyle(stateColor)
                        }
                        .font(.subheadline)
                        
                        if let msg = printer.stateMessage, !msg.isEmpty {
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Connection info
            Section("Connection") {
                LabeledContent("Address", value: printer.hostname)
                LabeledContent("Port", value: "\(printer.port)")
                LabeledContent("Path", value: printer.resourcePath)
                LabeledContent("Protocol", value: printer.useSSL ? "IPPS (Secure)" : "IPP")
                LabeledContent("URI", value: printer.uri)
                    .textSelection(.enabled)
            }
            
            // Device info
            Section("Device Info") {
                if let model = printer.makeAndModel {
                    LabeledContent("Model", value: model)
                }
                if let location = printer.location {
                    LabeledContent("Location", value: location)
                }
                if let firmware = printer.firmwareVersion {
                    LabeledContent("Firmware", value: firmware)
                }
                LabeledContent("Last Seen", value: printer.lastSeen.formatted())
            }
            
            // Capabilities
            Section("Capabilities") {
                CapabilityRow(name: "Color Printing", supported: printer.supportsColor)
                CapabilityRow(name: "Duplex Printing", supported: printer.supportsDuplex)
                CapabilityRow(name: "Page Ranges", supported: printer.supportsPageRanges)
                LabeledContent("Max Copies", value: "\(printer.maxCopies)")
            }
            
            // Supported media
            if !printer.supportedMediaSizes.isEmpty {
                Section("Supported Paper Sizes") {
                    FlowLayout(spacing: 6) {
                        ForEach(printer.supportedMediaSizes, id: \.self) { size in
                            let displayName = PrintSettings.PaperSize(rawValue: size)?.displayName ?? size
                            Text(displayName)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.accentColor.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            // Supported formats
            if !printer.supportedDocumentFormats.isEmpty {
                Section("Supported Document Formats") {
                    FlowLayout(spacing: 6) {
                        ForEach(printer.supportedDocumentFormats, id: \.self) { format in
                            Text(format)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.green.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            // Actions
            Section {
                Button {
                    printerVM.storage.toggleFavorite(printer)
                } label: {
                    Label(
                        printer.isFavorite ? "Remove from Favorites" : "Set as Default Printer",
                        systemImage: printer.isFavorite ? "star.slash" : "star.fill"
                    )
                }
                
                Button {
                    isRefreshing = true
                    printerVM.selectPrinter(printer)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isRefreshing = false
                    }
                } label: {
                    HStack {
                        Label("Refresh Printer Info", systemImage: "arrow.clockwise")
                        if isRefreshing {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                
                if printerVM.storage.isSaved(printer) {
                    Button(role: .destructive) {
                        printerVM.removePrinter(printer)
                    } label: {
                        Label("Remove Printer", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Printer Details")
    }
    
    private var stateColor: Color {
        switch printer.state {
        case .idle: return .green
        case .processing: return .blue
        case .stopped: return .red
        case .unknown: return .secondary
        }
    }
}

struct CapabilityRow: View {
    let name: String
    let supported: Bool
    
    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Image(systemName: supported ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(supported ? .green : .secondary)
        }
    }
}
