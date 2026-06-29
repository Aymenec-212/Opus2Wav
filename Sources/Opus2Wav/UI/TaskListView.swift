import SwiftUI

struct TaskListView: View {
    @EnvironmentObject private var engine: ConversionEngine

    var body: some View {
        Group {
            if engine.tasks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(engine.tasks) { task in
                            TaskRowView(task: task)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("Queue is empty")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Drop one or more .opus files above to begin.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
