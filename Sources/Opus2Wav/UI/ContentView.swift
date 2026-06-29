import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var engine: ConversionEngine

    var body: some View {
        VStack(spacing: 0) {
            DropZoneView()
                .padding(16)
            Divider()
            TaskListView()
            Divider()
            ControlBarView()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .top) {
            if let error = engine.lastEngineError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.85), in: Capsule())
                    .padding(.top, 8)
            }
        }
    }
}

#Preview {
    ContentView().environmentObject(ConversionEngine())
}
