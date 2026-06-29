import SwiftUI

struct TaskRowView: View {
    let task: ConversionTask

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.sourceURL.lastPathComponent)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                ProgressView(value: max(0, min(task.progress, 1)))
                    .progressViewStyle(.linear)
                    .tint(progressTint)
                Text(task.status.label)
                    .font(.caption)
                    .foregroundStyle(captionTint)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text("\(Int((task.progress * 100).rounded()))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch task.status {
        case .queued:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        case .extractingMetadata, .processing:
            ProgressView().controlSize(.small)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.octagon.fill")
                .foregroundStyle(.red)
        }
    }

    private var progressTint: Color {
        switch task.status {
        case .completed: return .green
        case .failed: return .red
        default: return .accentColor
        }
    }

    private var captionTint: Color {
        switch task.status {
        case .failed: return .red
        case .completed: return .green
        default: return .secondary
        }
    }
}
