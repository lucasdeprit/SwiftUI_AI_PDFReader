import Foundation

/// Represents an image note extracted from a page.
struct PageImage: Identifiable, Hashable {
    let id = UUID()
    let pageIndex: Int
    let description: String
}
