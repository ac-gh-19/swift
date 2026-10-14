import Foundation
import Testing
@testable import MusicMod

/// Checks what the screen state looks like after each kind of pick. Uses a
/// real `SongImporter` pointed at a temp folder, so nothing is faked.
@MainActor
struct ImportViewModelTests {
    let workDirectory: URL
    let viewModel: ImportViewModel

    init() throws {
        workDirectory = try AudioFixtures.makeTempDirectory()
        let importer = SongImporter(importsDirectory: workDirectory.appending(path: "Imports", directoryHint: .isDirectory))
        viewModel = ImportViewModel(importer: importer)
    }

    @Test func fileBreakingBothRulesShowsBothMessages() async throws {
        let source = try AudioFixtures.writeTone(in: workDirectory, fileExtension: "caf", seconds: 360)

        await viewModel.importSong(from: source)

        #expect(viewModel.song == nil)
        #expect(viewModel.errorMessages == [
            "Only MP3, M4A, WAV, AIFF, and FLAC files are accepted.",
            "Only songs 5 minutes or shorter are accepted.",
        ])
    }

    @Test func rejectedPickKeepsCurrentSongAndShowsErrors() async throws {
        let good = try AudioFixtures.writeTone(in: workDirectory, name: "good", fileExtension: "wav", seconds: 2)
        let bad = try AudioFixtures.writeFakeAudio(in: workDirectory, fileExtension: "mp3")

        await viewModel.importSong(from: good)
        await viewModel.importSong(from: bad)

        #expect(viewModel.song?.displayName == "good.wav")
        #expect(viewModel.errorMessages == [ImportRejection.unreadable.message])
    }

    @Test func goodPickAfterErrorClearsErrors() async throws {
        let bad = try AudioFixtures.writeTone(in: workDirectory, name: "long", fileExtension: "wav", seconds: 360)
        let good = try AudioFixtures.writeTone(in: workDirectory, name: "good", fileExtension: "wav", seconds: 2)

        await viewModel.importSong(from: bad)
        #expect(viewModel.errorMessages == [ImportRejection.tooLong.message])

        await viewModel.importSong(from: good)
        #expect(viewModel.song?.displayName == "good.wav")
        #expect(viewModel.errorMessages.isEmpty)
    }

    @Test func cancellingThePickerChangesNothing() async {
        await viewModel.handlePickerResult(.failure(CocoaError(.userCancelled)))

        #expect(viewModel.song == nil)
        #expect(viewModel.errorMessages.isEmpty)
    }
}
