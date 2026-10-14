import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @State private var viewModel = ImportViewModel()
    @State private var isPickerPresented = false

    var body: some View {
        VStack(spacing: 24) {
            if let song = viewModel.song {
                VStack(spacing: 4) {
                    Text(song.displayName)
                        .font(.headline)
                    Text(Duration.seconds(song.duration).formatted(.time(pattern: .minuteSecond)))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No song imported")
                    .foregroundStyle(.secondary)
            }

            Button("Import Song") {
                isPickerPresented = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isImporting)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.errorMessages, id: \.self) { message in
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .padding()
        .fileImporter(isPresented: $isPickerPresented, allowedContentTypes: [.audio]) { result in
            Task { await viewModel.handlePickerResult(result) }
        }
    }
}

#Preview {
    ImportView()
}
