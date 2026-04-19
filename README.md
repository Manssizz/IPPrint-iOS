# IPPrint - iOS IPP Printer App

Aplikasi printer untuk iPhone yang menggunakan protokol **IPP (Internet Printing Protocol)** secara langsung, tanpa perlu AirPrint. Cocok untuk printer yang support IPP tapi tidak support AirPrint.

## Fitur

### Printing
- **Print Dokumen** — PDF, gambar (JPEG/PNG/GIF/TIFF/BMP), teks
- **Print Foto** — Langsung dari Photo Library dengan layout options
- **Print Web Page** — Masukkan URL, render halaman web ke PDF lalu print
- **Print dari Clipboard** — Paste teks atau gambar untuk di-print

### Printer Management
- **Auto Discovery** — Cari printer otomatis via Bonjour/mDNS di jaringan lokal
- **Manual Add** — Tambah printer manual dengan IP address
- **Test Connection** — Cek koneksi sebelum menyimpan printer
- **Saved Printers** — Simpan printer favorit, set default printer
- **Printer Details** — Lihat info lengkap: model, firmware, capabilities

### Print Settings (IPP 2.0)
- **Copies** — Atur jumlah salinan
- **Paper Size** — A4, A3, A5, Letter, Legal, 4×6 Photo, 5×7 Photo
- **Orientation** — Portrait / Landscape
- **Color Mode** — Color, Black & White, Auto
- **Print Quality** — Draft, Normal, High Quality
- **Duplex** — Single sided, Double sided (long/short edge)
- **Page Range** — All pages atau range tertentu
- **Media Type** — Plain, Photo, Glossy, Matte, Envelope, dll
- **Fit to Page** — Otomatis sesuaikan ukuran ke kertas

### Print Queue
- **Job Monitoring** — Lihat status print job (pending, printing, completed, failed)
- **Cancel Job** — Batalkan job yang sedang berjalan
- **Job History** — Riwayat semua print job

### Lainnya
- **Share Extension ready** — Struktur siap untuk menerima file dari app lain
- **iPad support** — UI adaptive untuk iPhone dan iPad
- **Dark Mode** — Full dark mode support

## Arsitektur

```
IPPrint/
├── Sources/
│   ├── App/
│   │   ├── IPPrintApp.swift          # Entry point
│   │   └── ContentView.swift         # Main tab navigation
│   ├── Models/
│   │   ├── IPPModels.swift           # IPP protocol constants & types
│   │   ├── Printer.swift             # Printer data model
│   │   └── PrintJob.swift            # Print job data model
│   ├── Services/
│   │   ├── IPPService.swift          # IPP network engine (core)
│   │   ├── PrinterDiscoveryService.swift  # Bonjour/mDNS discovery
│   │   └── PrinterStorage.swift      # UserDefaults persistence
│   ├── ViewModels/
│   │   ├── PrinterViewModel.swift    # Printer state management
│   │   └── PrintJobViewModel.swift   # Print job state management
│   ├── Views/
│   │   ├── PrinterDiscoveryView.swift    # Network scanner UI
│   │   ├── PrintSettingsView.swift       # Full print settings
│   │   ├── DocumentPickerView.swift      # File picker
│   │   ├── PrintPreviewView.swift        # PDF/Image/Text preview
│   │   ├── PrintQueueView.swift          # Job queue & history
│   │   ├── PrinterDetailView.swift       # Printer info & capabilities
│   │   ├── ManualPrinterView.swift       # Manual printer entry
│   │   ├── PhotoPrintView.swift          # Photo printing
│   │   ├── WebPrintView.swift            # Web page printing
│   │   └── SavedPrintersView.swift       # Saved printer management
│   └── Utils/
│       ├── IPPEncoder.swift          # IPP binary protocol encoder
│       └── IPPDecoder.swift          # IPP binary protocol decoder
├── Resources/
│   └── Assets.xcassets
├── Info.plist
└── IPPrint.xcodeproj
```

## Cara Build

### Option 1: Build di Xcode (Local)
1. Clone repo ini
2. Buka `IPPrint.xcodeproj` di Xcode 16+
3. Pilih target device/simulator
4. Build & Run (⌘R)

### Option 2: Build via GitHub Actions
1. Push ke GitHub
2. GitHub Actions akan otomatis build
3. Download artifact dari tab Actions
4. File `.app` bisa di-sideload ke iPhone via:
   - **AltStore** — Install AltStore, lalu sideload .ipa
   - **Sideloadly** — Drag & drop .ipa
   - **TrollStore** — Jika device support

### Sideloading ke iPhone

Karena app ini tidak di App Store, ada beberapa cara install:

1. **Dengan Apple Developer Account ($99/tahun)**:
   - Tambahkan signing certificate di GitHub Actions secrets
   - Update workflow untuk sign & export .ipa
   - Install via TestFlight atau langsung

2. **Tanpa Developer Account (gratis)**:
   - Build via Xcode dengan Apple ID biasa (7-day signing)
   - Atau gunakan AltStore untuk re-sign setiap 7 hari

3. **TrollStore (jailbreak/exploit)**:
   - Install permanent tanpa signing

## Konfigurasi Printer

### Path Umum IPP
Kebanyakan printer menggunakan salah satu dari path berikut:
- `/ipp/print` — Paling umum (HP, Brother, Canon, Epson)
- `/ipp/printer` — Beberapa model Canon/Epson
- `/printers/default` — CUPS-based printers (Linux)
- `/ipp/port1` — Beberapa model Samsung

### Port Default
- **631** — IPP standard (tanpa SSL)
- **443** — IPPS (dengan SSL)

### Troubleshooting
- Pastikan printer dan iPhone di jaringan WiFi yang sama
- Coba test connection sebelum print
- Jika auto-discovery tidak menemukan, tambahkan manual dengan IP
- Cek apakah printer support IPP di halaman web admin printer (biasanya http://IP-PRINTER:80)

## Protokol IPP

App ini mengimplementasi IPP 2.0 secara native (tanpa library tambahan):
- **Get-Printer-Attributes** — Query printer capabilities
- **Print-Job** — Kirim dokumen untuk di-print
- **Validate-Job** — Validasi setting sebelum print
- **Get-Jobs** — Lihat antrian print
- **Get-Job-Attributes** — Status detail per-job
- **Cancel-Job** — Batalkan print job

## Requirements
- iOS 16.0+
- Xcode 16.0+
- Swift 5.9+

## License
MIT
