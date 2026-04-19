import SwiftUI
import PhotosUI

struct PhotoPickerView: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (UIImage) -> Void
        
        init(onPick: @escaping (UIImage) -> Void) {
            self.onPick = onPick
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let result = results.first else { return }
            
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                if let image = object as? UIImage {
                    DispatchQueue.main.async {
                        self?.onPick(image)
                    }
                }
            }
        }
    }
}

// MARK: - Photo Print View (multi-select + layout options)

struct PhotoPrintView: View {
    @EnvironmentObject var printJobVM: PrintJobViewModel
    @EnvironmentObject var printerVM: PrinterViewModel
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var loadedImages: [UIImage] = []
    @State private var layout: PhotoLayout = .single
    @State private var showPicker = true
    
    enum PhotoLayout: String, CaseIterable, Identifiable {
        case single = "Single"
        case two = "2 per page"
        case four = "4 per page"
        case wallet = "Wallet (8)"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if loadedImages.isEmpty {
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 20, matching: .images) {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 48))
                                .foregroundStyle(.accent)
                            
                            Text("Select Photos")
                                .font(.headline)
                            
                            Text("Choose photos from your library to print")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Layout picker
                            Picker("Layout", selection: $layout) {
                                ForEach(PhotoLayout.allCases) { l in
                                    Text(l.rawValue).tag(l)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                            
                            // Preview grid
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 100))
                            ], spacing: 8) {
                                ForEach(Array(loadedImages.enumerated()), id: \.offset) { idx, image in
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .padding(.horizontal)
                            
                            Text("\(loadedImages.count) photo\(loadedImages.count > 1 ? "s" : "") selected")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Print button
                    Button {
                        printPhotos()
                    } label: {
                        Label("Print \(loadedImages.count) Photo\(loadedImages.count > 1 ? "s" : "")",
                              systemImage: "printer.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding()
                }
            }
            .navigationTitle("Print Photos")
            .onChange(of: selectedPhotos) { _, items in
                loadPhotos(from: items)
            }
        }
    }
    
    private func loadPhotos(from items: [PhotosPickerItem]) {
        loadedImages.removeAll()
        
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                if case .success(let data) = result, let data = data,
                   let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        loadedImages.append(image)
                    }
                }
            }
        }
    }
    
    private func printPhotos() {
        guard let first = loadedImages.first else { return }
        printJobVM.loadImage(first)
        
        // Set photo defaults
        printJobVM.settings.mediaType = .photo
        printJobVM.settings.quality = .high
        printJobVM.settings.paperSize = .photo4x6
    }
}
