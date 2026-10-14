import Foundation

/// A song that passed validation and was copied into the app's container.
nonisolated struct ImportedSong: Equatable, Sendable {
    /// The app's own copy of the file (never the user's original).
    let fileURL: URL
    /// The original file name, e.g. "My Song.mp3".
    let displayName: String
    /// Length in seconds.
    let duration: TimeInterval
}
