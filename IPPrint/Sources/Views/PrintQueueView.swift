import SwiftUI

struct PrintQueueView: View {
    @EnvironmentObject var printJobVM: PrintJobViewModel
    @EnvironmentObject var printerVM: PrinterViewModel
    
    var body: some View {
        Group {
            if printJobVM.jobHistory.isEmpty {
                emptyState
            } else {
                jobList
            }
        }
        .toolbar {
            if !printJobVM.jobHistory.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear Done") {
                        printJobVM.clearHistory()
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Print Jobs")
                .font(.title3.weight(.medium))
            
            Text("Your print history will appear here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var jobList: some View {
        List {
            // Active jobs
            let activeJobs = printJobVM.jobHistory.filter { $0.status.isActive }
            if !activeJobs.isEmpty {
                Section("Active") {
                    ForEach(activeJobs) { job in
                        JobRow(job: job) {
                            if let printer = printerVM.selectedPrinter {
                                printJobVM.cancelJob(job, printer: printer)
                            }
                        }
                    }
                }
            }
            
            // Completed jobs
            let completedJobs = printJobVM.jobHistory.filter { !$0.status.isActive }
            if !completedJobs.isEmpty {
                Section("History") {
                    ForEach(completedJobs) { job in
                        JobRow(job: job, onCancel: nil)
                    }
                }
            }
        }
    }
}

struct JobRow: View {
    let job: PrintJob
    let onCancel: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                
                if job.status == .processing {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: job.status.iconName)
                        .font(.subheadline)
                        .foregroundStyle(statusColor)
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(job.documentName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(job.printerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                    
                    Text(job.submittedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 6) {
                    Text(job.status.displayName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(statusColor)
                    
                    if let msg = job.statusMessage {
                        Text("— \(msg)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            if let onCancel = onCancel, job.status.isActive {
                Button(role: .destructive) {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch job.status {
        case .pending: return .orange
        case .processing: return .blue
        case .completed: return .green
        case .cancelled: return .secondary
        case .failed: return .red
        case .held: return .yellow
        case .aborted: return .red
        }
    }
}
