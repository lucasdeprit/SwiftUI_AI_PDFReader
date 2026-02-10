import Foundation
import CryptoKit

/// Simple JSON cache keyed by SHA-256 hash of the PDF file.
final class DocumentCache {
    private let folderURL: URL

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        folderURL = (caches ?? FileManager.default.temporaryDirectory).appendingPathComponent("PDFAIReaderCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }

    /// Loads cached OCR + analysis for a given file URL.
    func load(for url: URL) async -> CachedDocument? {
        guard let key = await hash(for: url) else { return nil }
        let fileURL = folderURL.appendingPathComponent("\(key).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(CachedDocument.self, from: data)
    }

    /// Saves OCR + analysis to cache.
    func save(_ cached: CachedDocument, for url: URL) async {
        guard let key = await hash(for: url) else { return }
        let fileURL = folderURL.appendingPathComponent("\(key).json")
        if let data = try? JSONEncoder().encode(cached) {
            try? data.write(to: fileURL)
        }
    }

    /// Removes a single cached entry.
    func invalidate(for url: URL) async {
        guard let key = await hash(for: url) else { return }
        let fileURL = folderURL.appendingPathComponent("\(key).json")
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Clears all cached entries.
    func clearAll() async {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else { return }
        for fileURL in contents {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private func hash(for url: URL) async -> String? {
        await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: url) else { return nil }
            let digest = SHA256.hash(data: data)
            return digest.compactMap { String(format: "%02x", $0) }.joined()
        }.value
    }
}

/// Cached payload stored on disk.
struct CachedDocument: Codable {
    let ocrText: String
    let analysis: DocAnalysis
}
