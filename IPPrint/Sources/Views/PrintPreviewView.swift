import SwiftUI
import PDFKit

struct PrintPreviewView: View {
    let documentData: Data
    let mimeType: String
    let settings: PrintSettings
    
    var body: some View {
        Group {
            if mimeType == "application/pdf" {
                PDFPreview(data: documentData)
            } else if mimeType.starts(with: "image/") {
                ImagePreview(data: documentData, settings: settings)
            } else {
                TextPreview(data: documentData)
            }
        }
    }
}

// MARK: - PDF Preview

struct PDFPreview: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(data: data)
        pdfView.backgroundColor = .systemGroupedBackground
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Image Preview

struct ImagePreview: View {
    let data: Data
    let settings: PrintSettings
    
    var body: some View {
        if let image = UIImage(data: data) {
            ScrollView {
                VStack {
                    // Paper simulation
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: settings.fitToPage ? .fit : .fill)
                            .padding(20)
                    }
                    .aspectRatio(
                        settings.orientation == .portrait ? 0.707 : 1.414,
                        contentMode: .fit
                    )
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

// MARK: - Text Preview

struct TextPreview: View {
    let data: Data
    
    var body: some View {
        ScrollView {
            if let text = String(data: data, encoding: .utf8) {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Unable to preview this document")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
