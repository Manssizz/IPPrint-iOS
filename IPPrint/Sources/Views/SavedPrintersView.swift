import SwiftUI

struct SavedPrintersView: View {
    @EnvironmentObject var printerVM: PrinterViewModel
    @State private var showDiscovery = false
    @State private var showManualAdd = false
    
    var body: some View {
        Group {
            if printerVM.storage.savedPrinters.isEmpty {
                emptyState
            } else {
                printerList
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showDiscovery = true
                    } label: {
                        Label("Search Network", systemImage: "wifi")
                    }
                    
                    Button {
                        showManualAdd = true
                    } label: {
                        Label("Add Manually", systemImage: "keyboard")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showDiscovery) {
            NavigationStack {
                PrinterDiscoveryView { printer in
                    printerVM.savePrinter(printer)
                    printerVM.selectPrinter(printer)
                    showDiscovery = false
                }
                .navigationTitle("Find Printers")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showDiscovery = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showManualAdd) {
            NavigationStack {
                ManualPrinterView { name, host, port, path, ssl in
                    printerVM.addManualPrinter(name: name, hostname: host, port: port, path: path, ssl: ssl)
                    showManualAdd = false
                }
                .navigationTitle("Add Printer")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showManualAdd = false }
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "printer.dotmatrix.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            
            Text("No Saved Printers")
                .font(.title3.weight(.medium))
            
            Text("Add a printer to get started. You can search your network or add one manually.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            HStack(spacing: 12) {
                Button {
                    showDiscovery = true
                } label: {
                    Label("Search", systemImage: "wifi")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                
                Button {
                    showManualAdd = true
                } label: {
                    Label("Add Manual", systemImage: "keyboard")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var printerList: some View {
        List {
            // Favorites
            let favorites = printerVM.storage.savedPrinters.filter { $0.isFavorite }
            if !favorites.isEmpty {
                Section("Default Printer") {
                    ForEach(favorites) { printer in
                        NavigationLink {
                            PrinterDetailView(printer: printer)
                        } label: {
                            SavedPrinterRow(printer: printer)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                printerVM.removePrinter(printer)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                printerVM.storage.toggleFavorite(printer)
                            } label: {
                                Label("Unfavorite", systemImage: "star.slash")
                            }
                            .tint(.yellow)
                        }
                    }
                }
            }
            
            // Other printers
            let others = printerVM.storage.savedPrinters.filter { !$0.isFavorite }
            if !others.isEmpty {
                Section("Other Printers") {
                    ForEach(others) { printer in
                        NavigationLink {
                            PrinterDetailView(printer: printer)
                        } label: {
                            SavedPrinterRow(printer: printer)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                printerVM.removePrinter(printer)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                printerVM.storage.toggleFavorite(printer)
                            } label: {
                                Label("Favorite", systemImage: "star.fill")
                            }
                            .tint(.yellow)
                        }
                    }
                }
            }
        }
    }
}

struct SavedPrinterRow: View {
    let printer: Printer
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(stateColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "printer.fill")
                    .foregroundStyle(stateColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(printer.name)
                        .font(.subheadline.weight(.medium))
                    
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
                
                Text(printer.hostname + ":\(printer.port)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
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
