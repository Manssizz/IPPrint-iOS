import SwiftUI
import WebKit

struct WebPrintView: View {
    @EnvironmentObject var printJobVM: PrintJobViewModel
    @EnvironmentObject var printerVM: PrinterViewModel
    @State private var urlString = ""
    @State private var isLoading = false
    @State private var webData: Data?
    @State private var pageTitle: String?
    @State private var showWebView = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // URL Bar
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)
                
                TextField("Enter website URL", text: $urlString)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { loadURL() }
                
                if !urlString.isEmpty {
                    Button {
                        urlString = ""
                        webData = nil
                        showWebView = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Button {
                    loadURL()
                } label: {
                    Text("Go")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .disabled(urlString.isEmpty)
            }
            .padding()
            .background(.bar)
            
            Divider()
            
            if showWebView, let url = URL(string: normalizedURL) {
                // Web view preview
                WebViewPreview(url: url, isLoading: $isLoading, pageTitle: $pageTitle, pdfData: $webData)
                
                // Print bar
                VStack(spacing: 12) {
                    if isLoading {
                        ProgressView("Loading page...")
                    }
                    
                    if let title = pageTitle {
                        Text(title)
                            .font(.subheadline)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button {
                        printWebPage()
                    } label: {
                        Label("Print This Page", systemImage: "printer.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isLoading || webData == nil)
                }
                .padding()
                .background(.bar)
            } else {
                // Empty state
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "globe")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    
                    Text("Enter a URL to print a web page")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Quick access buttons
                    VStack(spacing: 8) {
                        QuickURLButton(title: "Google", url: "https://google.com") {
                            urlString = "https://google.com"
                            loadURL()
                        }
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    private var normalizedURL: String {
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        }
        return "https://\(urlString)"
    }
    
    private func loadURL() {
        guard !urlString.isEmpty else { return }
        showWebView = true
        isLoading = true
    }
    
    private func printWebPage() {
        guard let data = webData else { return }
        
        printJobVM.selectedDocumentData = data
        printJobVM.selectedDocumentName = (pageTitle ?? urlString) + ".pdf"
        printJobVM.selectedDocumentMimeType = "application/pdf"
        printJobVM.documentPageCount = nil
        
        dismiss()
    }
}

// MARK: - WebView Preview

struct WebViewPreview: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var pageTitle: String?
    @Binding var pdfData: Data?
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebViewPreview
        
        init(parent: WebViewPreview) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.pageTitle = webView.title
            }
            
            // Generate PDF from web page
            webView.createPDF { [weak self] result in
                switch result {
                case .success(let data):
                    DispatchQueue.main.async {
                        self?.parent.pdfData = data
                    }
                case .failure:
                    break
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
    }
}

struct QuickURLButton: View {
    let title: String
    let url: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "link")
                Text(title)
                Spacer()
                Text(url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}
