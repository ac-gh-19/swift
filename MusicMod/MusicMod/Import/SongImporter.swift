import AVFoundation

/// Checks a picked file against the import rules and copies accepted songs
/// into the app's container.
///
/// `nonisolated` opts this type out of the project-wide main-actor default,
/// so its disk work can run on a background thread.
nonisolated struct SongImporter {
    enum Outcome: Equatable, Sendable {
        case imported(ImportedSong)
        case rejected([ImportRejection])
    }

    static let acceptedExtensions: Set<String> = ["mp3", "m4a", "wav", "aif", "aiff", "flac"]
    static let maxDuration: TimeInterval = 5 * 60

    /// Players show length in whole seconds, so a song displayed as "5:00" can
    /// really be up to 5:00.999. Anything under 5:01 is accepted.
    static func isAllowedLength(_ duration: TimeInterval) -> Bool {
        duration < maxDuration + 1
    }

    /// Folder holding the one imported song. Each import goes in its own
    /// subfolder so a re-import of the same file name never collides.
    let importsDirectory: URL

    init(importsDirectory: URL = .applicationSupportDirectory.appending(path: "Imports", directoryHint: .isDirectory)) {
        self.importsDirectory = importsDirectory
    }

    /// Validates the file and, if it passes, copies it in and deletes the
    /// previous import. `@concurrent` makes this run off the main actor so the
    /// UI stays responsive while the file is read and copied.
    @concurrent
    func importSong(from url: URL) async -> Outcome {
        // Files from the picker live outside our sandbox; we only have
        // temporary permission to read them between start and stop.
        let hasScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasScopedAccess { url.stopAccessingSecurityScopedResource() }
        }

        let duration = Self.readDuration(of: url)
        let rejections = Self.validate(fileExtension: url.pathExtension, duration: duration)
        guard rejections.isEmpty, let duration else {
            return .rejected(rejections)
        }

        do {
            let copyURL = try copyReplacingPreviousImport(url)
            return .imported(ImportedSong(fileURL: copyURL, displayName: url.lastPathComponent, duration: duration))
        } catch {
            return .rejected([.saveFailed])
        }
    }

    /// Applies every rule and returns all failures, not just the first.
    /// `duration` is nil when the file couldn't be opened as audio.
    static func validate(fileExtension: String, duration: TimeInterval?) -> [ImportRejection] {
        let formatAccepted = acceptedExtensions.contains(fileExtension.lowercased())
        var rejections: [ImportRejection] = []

        if !formatAccepted {
            rejections.append(.unsupportedFormat)
        }
        if let duration {
            if !isAllowedLength(duration) {
                rejections.append(.tooLong)
            }
        } else if formatAccepted {
            // An unsupported file that can't be read is already explained by
            // the format error, so "unreadable" is only added for accepted types.
            rejections.append(.unreadable)
        }
        return rejections
    }

    /// Reads the length from the file header without decoding the audio.
    static func readDuration(of url: URL) -> TimeInterval? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        return Double(file.length) / file.processingFormat.sampleRate
    }

    /// Copies the file into a fresh subfolder, then deletes older imports.
    /// The old song is only removed after the new copy succeeds.
    private func copyReplacingPreviousImport(_ source: URL) throws -> URL {
        let fileManager = FileManager.default
        let newFolder = importsDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: newFolder, withIntermediateDirectories: true)

        let destination = newFolder.appending(path: source.lastPathComponent)
        do {
            try fileManager.copyItem(at: source, to: destination)
        } catch {
            try? fileManager.removeItem(at: newFolder)
            throw error
        }

        let existing = try fileManager.contentsOfDirectory(at: importsDirectory, includingPropertiesForKeys: nil)
        for folder in existing where folder.lastPathComponent != newFolder.lastPathComponent {
            try? fileManager.removeItem(at: folder)
        }
        return destination
    }
}
