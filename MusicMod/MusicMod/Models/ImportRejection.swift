import Foundation

/// A reason a picked file was not imported. One file can have several.
nonisolated enum ImportRejection: Equatable, Sendable {
    case unsupportedFormat
    case tooLong
    case unreadable
    case saveFailed

    /// The text shown to the user.
    var message: String {
        switch self {
        case .unsupportedFormat:
            "Only MP3, M4A, WAV, AIFF, and FLAC files are accepted."
        case .tooLong:
            "Only songs \(Int(SongImporter.maxDuration / 60)) minutes or shorter are accepted."
        case .unreadable:
            "This file couldn't be read. It may be damaged or not a real audio file."
        case .saveFailed:
            "The song couldn't be saved. Check that your device has free storage and try again."
        }
    }
}
