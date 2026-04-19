import SwiftUI

struct PrintSettingsView: View {
    @Binding var settings: PrintSettings
    let printer: Printer?
    
    var body: some View {
        Form {
            // Copies
            Section("Copies") {
                Stepper(value: $settings.copies, in: 1...(printer?.maxCopies ?? 99)) {
                    HStack {
                        Text("Copies")
                        Spacer()
                        Text("\(settings.copies)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            
            // Paper & Layout
            Section("Paper & Layout") {
                Picker("Paper Size", selection: $settings.paperSize) {
                    ForEach(availablePaperSizes) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                
                Picker("Orientation", selection: $settings.orientation) {
                    ForEach([PrintSettings.Orientation.portrait, .landscape]) { orient in
                        Label(orient.displayName,
                              systemImage: orient == .portrait ? "rectangle.portrait" : "rectangle")
                        .tag(orient)
                    }
                }
                .pickerStyle(.segmented)
                
                Picker("Media Type", selection: $settings.mediaType) {
                    ForEach(PrintSettings.MediaType.allCases) { media in
                        Text(media.displayName).tag(media)
                    }
                }
                
                Toggle("Fit to Page", isOn: $settings.fitToPage)
            }
            
            // Quality & Color
            Section("Quality & Color") {
                Picker("Color Mode", selection: $settings.colorMode) {
                    ForEach(availableColorModes) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                
                Picker("Print Quality", selection: $settings.quality) {
                    ForEach(PrintSettings.PrintQuality.allCases) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Duplex
            if printer?.supportsDuplex ?? true {
                Section("Sides") {
                    Picker("Print Sides", selection: $settings.sides) {
                        ForEach(PrintSettings.Sides.allCases) { side in
                            Text(side.displayName).tag(side)
                        }
                    }
                }
            }
            
            // Page Range
            Section("Page Range") {
                PageRangePicker(pageRange: $settings.pageRange)
            }
            
            // Printer capabilities info
            if let printer = printer {
                Section("Printer Capabilities") {
                    LabeledContent("Color Support", value: printer.supportsColor ? "Yes" : "No")
                    LabeledContent("Duplex Support", value: printer.supportsDuplex ? "Yes" : "No")
                    LabeledContent("Max Copies", value: "\(printer.maxCopies)")
                    
                    if !printer.supportedDocumentFormats.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Supported Formats")
                                .font(.subheadline)
                            
                            FlowLayout(spacing: 6) {
                                ForEach(printer.supportedDocumentFormats, id: \.self) { format in
                                    Text(format.components(separatedBy: "/").last ?? format)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.accentColor.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var availablePaperSizes: [PrintSettings.PaperSize] {
        guard let printer = printer, !printer.supportedMediaSizes.isEmpty else {
            return PrintSettings.PaperSize.allCases
        }
        return PrintSettings.PaperSize.allCases.filter { size in
            printer.supportedMediaSizes.contains(size.rawValue)
        }
    }
    
    private var availableColorModes: [PrintSettings.ColorMode] {
        guard let printer = printer else {
            return PrintSettings.ColorMode.allCases
        }
        if printer.supportsColor {
            return PrintSettings.ColorMode.allCases
        }
        return [.monochrome]
    }
}

// MARK: - Page Range Picker

struct PageRangePicker: View {
    @Binding var pageRange: PrintSettings.PageRange
    @State private var isAll = true
    @State private var fromPage = "1"
    @State private var toPage = ""
    
    var body: some View {
        Toggle("All Pages", isOn: $isAll)
            .onChange(of: isAll) { _, newValue in
                if newValue {
                    pageRange = .all
                }
            }
        
        if !isAll {
            HStack {
                Text("From")
                TextField("1", text: $fromPage)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                
                Text("To")
                TextField("Last", text: $toPage)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
            }
            .onChange(of: fromPage) { _, _ in updateRange() }
            .onChange(of: toPage) { _, _ in updateRange() }
        }
    }
    
    private func updateRange() {
        guard let from = Int(fromPage), from > 0 else { return }
        if let to = Int(toPage), to >= from {
            pageRange = .range(from: from, to: to)
        } else if toPage.isEmpty {
            pageRange = .range(from: from, to: 9999)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                  proposal: .unspecified)
        }
    }
    
    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > width && x > 0 {
                x = 0
                y += maxHeight + spacing
                maxHeight = 0
            }
            
            positions.append(CGPoint(x: x, y: y))
            maxHeight = max(maxHeight, size.height)
            x += size.width + spacing
            totalHeight = y + maxHeight
        }
        
        return (CGSize(width: width, height: totalHeight), positions)
    }
}
