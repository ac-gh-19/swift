import AVFoundation
import Foundation
import Testing
@testable import MusicMod

/// Runs real audio files through `SongImporter` and checks what it accepts,
/// rejects, and writes to disk. Numbers refer to the test plan in
/// docs/specs/001-song-import.md.
struct SongImporterTests {
    let workDirectory: URL
    let importsDirectory: URL
    let importer: SongImporter

    init() throws {
        workDirectory = try AudioFixtures.makeTempDirectory()
        importsDirectory = workDirectory.appending(path: "Imports", directoryHint: .isDirectory)
        importer = SongImporter(importsDirectory: importsDirectory)
    }

    /// Every file currently stored under the imports folder.
    private func storedFiles() -> [URL] {
        let enumerator = FileManager.default.enumerator(at: importsDirectory, includingPropertiesForKeys: [.isRegularFileKey])
        return (enumerator?.allObjects as? [URL] ?? []).filter { !$0.hasDirectoryPath }
    }

    // MARK: 1 — all accepted formats import end to end

    @Test(arguments: ["wav", "aif", "m4a"])
    func generatedFormatIsImported(fileExtension: String) async throws {
        let rate: Double = fileExtension == "m4a" ? 44_100 : 8000
        let source = try AudioFixtures.writeTone(in: workDirectory, fileExtension: fileExtension, seconds: 2, sampleRate: rate)

        let outcome = await importer.importSong(from: source)

        try expectImported(outcome, originalName: source.lastPathComponent, expectedSeconds: 2)
    }

    @Test(arguments: ["short_tone.mp3", "short_tone.flac"])
    func bundledFormatIsImported(fileName: String) async throws {
        let source = try AudioFixtures.bundled(fileName)

        let outcome = await importer.importSong(from: source)

        try expectImported(outcome, originalName: fileName, expectedSeconds: 2)
    }

    /// Checks the song was accepted, the copy exists inside the imports folder,
    /// and the copy itself opens as audio with the right length.
    private func expectImported(_ outcome: SongImporter.Outcome, originalName: String, expectedSeconds: Double) throws {
        guard case .imported(let song) = outcome else {
            Issue.record("Expected import, got \(outcome)")
            return
        }
        #expect(song.displayName == originalName)
        #expect(abs(song.duration - expectedSeconds) < 0.1)
        #expect(song.fileURL.path().hasPrefix(importsDirectory.path()))

        let copyDuration = try #require(SongImporter.readDuration(of: song.fileURL))
        #expect(abs(copyDuration - expectedSeconds) < 0.1)
    }

    // MARK: 2 — other audio formats are rejected

    @Test func cafIsRejectedAsUnsupported() async throws {
        let source = try AudioFixtures.writeTone(in: workDirectory, fileExtension: "caf", seconds: 2)

        #expect(await importer.importSong(from: source) == .rejected([.unsupportedFormat]))
    }

    @Test func oggIsRejectedAsUnsupported() async throws {
        let source = try AudioFixtures.bundled("short_tone.ogg")

        #expect(await importer.importSong(from: source) == .rejected([.unsupportedFormat]))
    }

    // MARK: 3–5 — the 5:00 boundary

    @Test func exactlyFiveMinutesIsAccepted() async throws {
        let source = try AudioFixtures.writeTone(in: workDirectory, fileExtension: "wav", frames: 300 * 8000)

        let outcome = await importer.importSong(from: source)

        guard case .imported(let song) = outcome else {
            Issue.record("Expected import, got \(outcome)")
            return
        }
        #expect(song.duration == 300)
    }

    @Test func justUnderFiveOhOneIsAccepted() async throws {
        // One sample short of 301 s, i.e. 5:00.999875 at 8 kHz.
        let source = try AudioFixtures.writeTone(in: workDirectory, fileExtension: "wav", frames: 301 * 8000 - 1)

        let outcome = await importer.importSong(from: source)

        guard case .imported = outcome else {
            Issue.record("Expected import, got \(outcome)")
            return
        }
    }

    @Test func fiveOhOneIsRejected() async throws {
        let source = try AudioFixtures.writeTone(in: workDirectory, fileExtension: "wav", frames: 301 * 8000)

        #expect(await importer.importSong(from: source) == .rejected([.tooLong]))
    }

    // MARK: 6 — length rule on compressed formats

    @Test(arguments: ["six_minutes.mp3", "six_minutes.flac"])
    func sixMinuteCompressedFileIsRejected(fileName: String) async throws {
        let source = try AudioFixtures.bundled(fileName)

        #expect(await importer.importSong(from: source) == .rejected([.tooLong]))
    }

    // MARK: 7 — both errors at once

    @Test func longUnsupportedFileReportsBothErrors() async throws {
        let source = try AudioFixtures.writeTone(in: workDirectory, fileExtension: "caf", seconds: 360)

        #expect(await importer.importSong(from: source) == .rejected([.unsupportedFormat, .tooLong]))
    }

    // MARK: 8 — damaged files

    @Test(arguments: ["mp3", "wav", "flac"])
    func fakeAudioFileIsUnreadable(fileExtension: String) async throws {
        let source = try AudioFixtures.writeFakeAudio(in: workDirectory, fileExtension: fileExtension)

        #expect(await importer.importSong(from: source) == .rejected([.unreadable]))
    }

    @Test func unreadableUnsupportedFileOnlyReportsFormat() async throws {
        let source = try AudioFixtures.writeFakeAudio(in: workDirectory, fileExtension: "wma")

        #expect(await importer.importSong(from: source) == .rejected([.unsupportedFormat]))
    }

    // MARK: 9 — rejected files are never copied, and don't touch the current song

    @Test func rejectedFileIsNotCopiedAndKeepsPreviousImport() async throws {
        let good = try AudioFixtures.writeTone(in: workDirectory, name: "good", fileExtension: "wav", seconds: 2)
        let tooLong = try AudioFixtures.writeTone(in: workDirectory, name: "long", fileExtension: "wav", seconds: 360)

        guard case .imported(let first) = await importer.importSong(from: good) else {
            Issue.record("Setup import failed")
            return
        }
        #expect(await importer.importSong(from: tooLong) == .rejected([.tooLong]))

        #expect(storedFiles().map(\.lastPathComponent) == ["good.wav"])
        #expect(FileManager.default.fileExists(atPath: first.fileURL.path()))
    }

    // MARK: 10 — a new import replaces the old one

    @Test func newImportReplacesPrevious() async throws {
        let songA = try AudioFixtures.writeTone(in: workDirectory, name: "A", fileExtension: "wav", seconds: 1)
        let songB = try AudioFixtures.writeTone(in: workDirectory, name: "B", fileExtension: "wav", seconds: 2)

        guard case .imported(let first) = await importer.importSong(from: songA),
              case .imported(let second) = await importer.importSong(from: songB) else {
            Issue.record("Imports failed")
            return
        }

        #expect(!FileManager.default.fileExists(atPath: first.fileURL.path()))
        #expect(FileManager.default.fileExists(atPath: second.fileURL.path()))
        #expect(storedFiles().map(\.lastPathComponent) == ["B.wav"])
    }

    @Test func reimportingSameFileNameWorks() async throws {
        let song = try AudioFixtures.writeTone(in: workDirectory, fileExtension: "wav", seconds: 1)

        guard case .imported = await importer.importSong(from: song),
              case .imported(let second) = await importer.importSong(from: song) else {
            Issue.record("Re-import failed")
            return
        }
        #expect(storedFiles().count == 1)
        #expect(FileManager.default.fileExists(atPath: second.fileURL.path()))
    }

    // MARK: Save failure

    @Test func copyFailureReportsSaveFailed() async throws {
        // Put a plain file where the imports folder should be, so the folder
        // can't be created and the copy fails.
        try Data().write(to: importsDirectory)
        let song = try AudioFixtures.writeTone(in: workDirectory, fileExtension: "wav", seconds: 1)

        #expect(await importer.importSong(from: song) == .rejected([.saveFailed]))
    }

    // MARK: 11 — message matches the limit

    @Test func tooLongMessageUsesTheLimit() {
        #expect(SongImporter.maxDuration == 300)
        #expect(ImportRejection.tooLong.message == "Only songs 5 minutes or shorter are accepted.")
    }
}
