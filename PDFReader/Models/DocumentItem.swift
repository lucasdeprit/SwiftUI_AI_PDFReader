import Foundation

/// Represents a PDF and its processing state.
struct DocumentItem: Identifiable, Hashable {
    let id: UUID
    let url: URL
    var title: String
    var status: DocumentStatus
    var progress: Double
    var ocrText: String?
    var analysis: DocAnalysis?
    var errorMessage: String?
    var isCached: Bool

    init(url: URL, title: String) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.status = .idle
        self.progress = 0
        self.ocrText = nil
        self.analysis = nil
        self.errorMessage = nil
        self.isCached = false
    }
}

/// Processing status for a document.
enum DocumentStatus: String, Hashable {
    case idle = "Listo"
    case ocr = "OCR"
    case analyzing = "Analizando"
    case done = "Hecho"
    case error = "Error"
}
