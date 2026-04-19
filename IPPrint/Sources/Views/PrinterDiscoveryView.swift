import SwiftUI

struct PrinterDiscoveryView: View {
    @StateObject private var discovery = PrinterDiscoveryService()
    @EnvironmentObject var printerVM: PrinterViewModel
    let onSelect: (Printer) -> Void
    
    var body: some View {
        List {
            // Saved printers section
            if !printerVM.storage.savedPrinters.isEmpty {
                Section("Saved Printers") {
                    ForEach(printerVM.storage.savedPrinters) { printer in
                        PrinterRow(printer: printer, isSaved: true) {
                            onSelect(printer)
                        }
                    }
                }
            }
            
            // Discovered printers section
            Section {
                if discovery.isSearching && discovery.discoveredPrinters.isEmpty {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Searching for printers on your network...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                ForEach(discovery.discoveredPrinters) { printer in
                    let alreadySaved = printerVM.storage.isSaved(printer)
                    PrinterRow(printer: printer, isSaved: alreadySaved) {
                        onSelect(printer)
                    }
                }
                
                if !discovery.isSearching && discovery.discoveredPrinters.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "printer.dotmatrix.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        
                        Text("No printers found")
                            .font(.headline)
                        
                        Text("Make sure your printer is turned on and connected to the same network.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Search Again") {
                            discovery.startDiscovery()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } header: {
                HStack {
                    Text("Network Printers")
                    Spacer()
                    if discovery.isSearching {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }
            
            if let error = discovery.error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .refreshable {
            discovery.startDiscovery()
        }
        .onAppear {
            discovery.startDiscovery()
        }
        .onDisappear {
            discovery.stopDiscovery()
        }
    }
}

struct PrinterRow: View {
    let printer: Printer
    let isSaved: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(stateColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "printer.fill")
                        .foregroundStyle(stateColor)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(printer.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        
                        if isSaved {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                        
                        if printer.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }
                    
                    if let model = printer.makeAndModel {
                        Text(model)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        Text(printer.hostname)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        
                        if printer.supportsColor {
                            Image(systemName: "paintpalette.fill")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        if printer.supportsDuplex {
                            Image(systemName: "rectangle.on.rectangle")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: printer.state.iconName)
                        .font(.caption)
                        .foregroundStyle(stateColor)
                    
                    Text(printer.state.displayName)
                        .font(.caption2)
                        .foregroundStyle(stateColor)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
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
