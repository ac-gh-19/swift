import AVFoundation
import Foundation

/// Creates real audio files for tests: generated ones (exact length) and the
/// committed ones in `Fixtures/` (formats iOS can't write: MP3, FLAC, OGG).
enum AudioFixtures {
    private final class BundleToken {}

    /// A fresh, empty temporary folder for one test.
    static func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "MusicModTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Writes a 440 Hz sine of exactly `frames` samples. The file type comes
    /// from `fileExtension` (wav, aif, caf, or m4a).
    static func writeTone(in directory: URL, name: String = "tone", fileExtension: String, frames: AVAudioFramePosition, sampleRate: Double = 8000) throws -> URL {
        let url = directory.appending(path: "\(name).\(fileExtension)")
        let file = try AVAudioFile(forWriting: url, settings: settings(for: fileExtension, sampleRate: sampleRate))
        let format = file.processingFormat

        let chunkSize: AVAudioFrameCount = 32_768
        var written: AVAudioFramePosition = 0
        while written < frames {
            let count = AVAudioFrameCount(min(AVAudioFramePosition(chunkSize), frames - written))
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count)!
            buffer.frameLength = count
            let samples = buffer.floatChannelData![0]
            for i in 0..<Int(count) {
                let t = Double(written + AVAudioFramePosition(i)) / format.sampleRate
                samples[i] = Float(0.5 * sin(2 * .pi * 440 * t))
            }
            try file.write(from: buffer)
            written += AVAudioFramePosition(count)
        }
        return url
    }

    /// Same as `writeTone`, sized in seconds.
    static func writeTone(in directory: URL, name: String = "tone", fileExtension: String, seconds: Double, sampleRate: Double = 8000) throws -> URL {
        try writeTone(in: directory, name: name, fileExtension: fileExtension, frames: AVAudioFramePosition(seconds * sampleRate), sampleRate: sampleRate)
    }

    /// A file that has an audio extension but contains plain text.
    static func writeFakeAudio(in directory: URL, fileExtension: String) throws -> URL {
        let url = directory.appending(path: "fake.\(fileExtension)")
        try Data("This is not audio, just text pretending to be a song.\n".utf8).write(to: url)
        return url
    }

    /// A committed fixture, e.g. `bundled("short_tone.mp3")`.
    static func bundled(_ fileName: String) throws -> URL {
        let bundle = Bundle(for: BundleToken.self)
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        guard let url = bundle.url(forResource: name, withExtension: ext)
                ?? bundle.url(forResource: name, withExtension: ext, subdirectory: "Fixtures") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: fileName])
        }
        return url
    }

    private static func settings(for fileExtension: String, sampleRate: Double) -> [String: Any] {
        if fileExtension == "m4a" {
            // The AAC encoder needs a standard rate, so callers pass 44_100 for m4a.
            return [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: sampleRate, AVNumberOfChannelsKey: 1]
        }
        return [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            // AIFF stores samples big-endian; WAV and CAF use little-endian.
            AVLinearPCMIsBigEndianKey: fileExtension == "aif" || fileExtension == "aiff",
        ]
    }
}
