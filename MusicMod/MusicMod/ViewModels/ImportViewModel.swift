import Foundation

/// Screen state for importing a song. `@Observable` makes SwiftUI redraw any
/// view that reads these properties whenever they change.
@Observable
final class ImportViewModel {
    /// The currently loaded song. Kept when a new pick is rejected.
    private(set) var song: ImportedSong?
    /// Errors for the most recent pick only. Cleared on the next pick.
    private(set) var errorMessages: [String] = []
    private(set) var isImporting = false

    private let importer: SongImporter

    init(importer: SongImporter = SongImporter()) {
        self.importer = importer
    }

    /// Called with whatever the Files picker returned.
    func handlePickerResult(_ result: Result<URL, any Error>) async {
        switch result {
        case .success(let url):
            await importSong(from: url)
        case .failure(let error as CocoaError) where error.code == .userCancelled:
            break
        case .failure:
            errorMessages = [ImportRejection.unreadable.message]
        }
    }

    func importSong(from url: URL) async {
        isImporting = true
        errorMessages = []
        defer { isImporting = false }

        switch await importer.importSong(from: url) {
        case .imported(let newSong):
            song = newSong
        case .rejected(let reasons):
            errorMessages = reasons.map(\.message)
        }
    }
}
