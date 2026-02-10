import Foundation

/// Structured analysis generated for a document.
struct DocAnalysis: Codable, Hashable {
    var summary: String
    var category: DocCategory
    var tags: [String]
}
