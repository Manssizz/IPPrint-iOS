import SwiftUI

struct ContentView: View {
    @EnvironmentObject var printerVM: PrinterViewModel
    @EnvironmentObject var printJobVM: PrintJobViewModel
    @State private var selectedTab = 0
    @State private var showDocumentPicker = false
    @State private var showPhotoPicker = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Print Tab
            NavigationStack {
                PrintHomeView(
                    showDocumentPicker: $showDocumentPicker,
                    showPhotoPicker: $showPhotoPicker
                )
                .navigationTitle("IPPrint")
            }
            .tabItem {
                Label("Print", systemImage: "printer.fill")
            }
            .tag(0)
            
            // Printers Tab
            NavigationStack {
                SavedPrintersView()
                    .navigationTitle("Printers")
            }
            .tabItem {
                Label("Printers", systemImage: "wifi.router.fill")
            }
            .tag(1)
            
            // Queue Tab
            NavigationStack {
                PrintQueueView()
                    .navigationTitle("Print Queue")
            }
            .tabItem {
                Label("Queue", systemImage: "list.bullet.rectangle.fill")
            }
            .tag(2)
            
            // Settings Tab
            NavigationStack {
                AppSettingsView()
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(3)
        }
        .tint(Color.accentColor)
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { url in
                printJobVM.loadDocument(url: url)
                selectedTab = 0
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPickerView { image in
                printJobVM.loadImage(image)
                selectedTab = 0
            }
        }
        .onAppear {
            if let defaultPrinter = printerVM.storage.defaultPrinter() {
                printerVM.selectPrinter(defaultPrinter)
            }
        }
    }
}

// MARK: - Print Home View

struct PrintHomeView: View {
    @EnvironmentObject var printerVM: PrinterViewModel
    @EnvironmentObject var printJobVM: PrintJobViewModel
    @Binding var showDocumentPicker: Bool
    @Binding var showPhotoPicker: Bool
    @State private var showPrinterPicker = false
    @State private var showPrintSettings = false
    @State private var showWebPrint = false
    @State private var showManualAdd = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Printer Selection Card
                printerCard
                
                // Source buttons
                if printJobVM.selectedDocumentData == nil {
                    sourceSelectionSection
                } else {
                    documentPreviewSection
                }
                
                // Print button
                if printJobVM.selectedDocumentData != nil && printerVM.selectedPrinter != nil {
                    printActionSection
                }
            }
            .padding()
        }
        .sheet(isPresented: $showPrinterPicker) {
            NavigationStack {
                PrinterDiscoveryView { printer in
                    printerVM.selectPrinter(printer)
                    printerVM.savePrinter(printer)
                    showPrinterPicker = false
                }
                .navigationTitle("Select Printer")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showPrinterPicker = false }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add Manual") {
                            showPrinterPicker = false
                            showManualAdd = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPrintSettings) {
            NavigationStack {
                PrintSettingsView(
                    settings: $printJobVM.settings,
                    printer: printerVM.selectedPrinter
                )
                .navigationTitle("Print Settings")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showPrintSettings = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showWebPrint) {
            NavigationStack {
                WebPrintView()
                    .navigationTitle("Print Web Page")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showWebPrint = false }
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
        .alert("Print Error", isPresented: $printJobVM.showError) {
            Button("OK") {}
        } message: {
            Text(printJobVM.error ?? "Unknown error")
        }
        .alert("Print Sent!", isPresented: $printJobVM.showSuccess) {
            Button("OK") {
                printJobVM.clearDocument()
            }
        } message: {
            Text("Your document has been sent to the printer successfully.")
        }
        .overlay {
            if printJobVM.isPrinting {
                printingOverlay
            }
        }
    }
    
    // MARK: - Printer Card
    
    private var printerCard: some View {
        Button {
            showPrinterPicker = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(printerVM.selectedPrinter != nil
                              ? Color.accentColor.opacity(0.15)
                              : Color.secondary.opacity(0.1))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: printerVM.selectedPrinter != nil
                          ? "printer.fill" : "printer.dotmatrix.fill")
                        .font(.title2)
                        .foregroundStyle(printerVM.selectedPrinter != nil
                                         ? Color.accentColor : .secondary)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    if let printer = printerVM.selectedPrinter {
                        Text(printer.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        HStack(spacing: 6) {
                            Image(systemName: printer.state.iconName)
                                .font(.caption)
                                .foregroundStyle(printer.state == .idle ? .green : .orange)
                            
                            Text(printer.makeAndModel ?? printer.state.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No Printer Selected")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Tap to find or add a printer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Source Selection
    
    private var sourceSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What do you want to print?")
                .font(.title3.bold())
                .padding(.top, 8)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                SourceCard(
                    icon: "doc.fill",
                    title: "Document",
                    subtitle: "PDF, images, text",
                    color: .blue
                ) {
                    showDocumentPicker = true
                }
                
                SourceCard(
                    icon: "photo.fill",
                    title: "Photo",
                    subtitle: "From library",
                    color: .green
                ) {
                    showPhotoPicker = true
                }
                
                SourceCard(
                    icon: "globe",
                    title: "Web Page",
                    subtitle: "Print from URL",
                    color: .orange
                ) {
                    showWebPrint = true
                }
                
                SourceCard(
                    icon: "doc.on.clipboard.fill",
                    title: "Clipboard",
                    subtitle: "Paste content",
                    color: .purple
                ) {
                    loadFromClipboard()
                }
            }
        }
    }
    
    // MARK: - Document Preview
    
    private var documentPreviewSection: some View {
        VStack(spacing: 16) {
            // Preview card
            VStack(spacing: 12) {
                if let thumb = printJobVM.documentThumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                }
                
                VStack(spacing: 4) {
                    Text(printJobVM.selectedDocumentName ?? "Document")
                        .font(.headline)
                        .lineLimit(2)
                    
                    HStack(spacing: 16) {
                        if let pages = printJobVM.documentPageCount {
                            Label("\(pages) page\(pages > 1 ? "s" : "")", systemImage: "doc.plaintext")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let mime = printJobVM.selectedDocumentMimeType {
                            Text(mime.components(separatedBy: "/").last?.uppercased() ?? "")
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        
                        if let data = printJobVM.selectedDocumentData {
                            Text(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    Button {
                        showPrintSettings = true
                    } label: {
                        Label("Settings", systemImage: "slider.horizontal.3")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    
                    Button(role: .destructive) {
                        printJobVM.clearDocument()
                    } label: {
                        Label("Remove", systemImage: "xmark")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 4)
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            }
            
            // Quick settings summary
            settingsSummary
        }
    }
    
    private var settingsSummary: some View {
        HStack(spacing: 16) {
            SettingBadge(icon: "doc.on.doc", text: "\(printJobVM.settings.copies)×")
            SettingBadge(icon: printJobVM.settings.colorMode == .color ? "paintpalette.fill" : "circle.lefthalf.filled",
                         text: printJobVM.settings.colorMode.displayName)
            SettingBadge(icon: "doc.plaintext", text: printJobVM.settings.paperSize.displayName)
            SettingBadge(icon: printJobVM.settings.orientation == .portrait ? "rectangle.portrait" : "rectangle",
                         text: printJobVM.settings.orientation.displayName)
            
            Spacer()
            
            Button {
                showPrintSettings = true
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Print Action
    
    private var printActionSection: some View {
        Button {
            guard let printer = printerVM.selectedPrinter else { return }
            Task {
                await printJobVM.printDocument(to: printer)
            }
        } label: {
            HStack {
                Image(systemName: "printer.fill")
                Text("Print")
                    .fontWeight(.semibold)
            }
            .font(.title3)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 4)
        }
        .disabled(printJobVM.isPrinting)
        .padding(.top, 8)
    }
    
    // MARK: - Printing Overlay
    
    private var printingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text(printJobVM.printProgress)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(40)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
    
    // MARK: - Actions
    
    private func loadFromClipboard() {
        if let image = UIPasteboard.general.image {
            printJobVM.loadImage(image)
        } else if let string = UIPasteboard.general.string,
                  let data = string.data(using: .utf8) {
            printJobVM.selectedDocumentData = data
            printJobVM.selectedDocumentName = "Clipboard_\(Date().formatted(.dateTime.hour().minute())).txt"
            printJobVM.selectedDocumentMimeType = "text/plain"
            printJobVM.documentPageCount = 1
        }
    }
}

// MARK: - Supporting Views

struct SourceCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                }
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct SettingBadge: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - App Settings View

struct AppSettingsView: View {
    @EnvironmentObject var printerVM: PrinterViewModel
    @AppStorage("defaultPaperSize") private var defaultPaperSize = "iso_a4_210x297mm"
    @AppStorage("defaultColorMode") private var defaultColorMode = "color"
    @AppStorage("defaultQuality") private var defaultQuality = "4"
    
    var body: some View {
        List {
            Section("Default Print Settings") {
                Picker("Paper Size", selection: $defaultPaperSize) {
                    ForEach(PrintSettings.PaperSize.allCases) { size in
                        Text(size.displayName).tag(size.rawValue)
                    }
                }
                
                Picker("Color Mode", selection: $defaultColorMode) {
                    ForEach(PrintSettings.ColorMode.allCases) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
                
                Picker("Print Quality", selection: $defaultQuality) {
                    ForEach(PrintSettings.PrintQuality.allCases) { quality in
                        Text(quality.displayName).tag(quality.rawValue)
                    }
                }
            }
            
            Section("Printers") {
                HStack {
                    Text("Saved Printers")
                    Spacer()
                    Text("\(printerVM.storage.savedPrinters.count)")
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Protocol")
                    Spacer()
                    Text("IPP 2.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
