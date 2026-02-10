import Foundation

/// Cached payload stored on disk.
struct CachedDocument: Codable {
    let ocrText: String
    let analysis: DocAnalysis
}
