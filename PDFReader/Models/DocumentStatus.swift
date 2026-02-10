import Foundation

/// Processing status for a document.
enum DocumentStatus: String, Hashable {
    case idle = "Listo"
    case ocr = "OCR"
    case analyzing = "Analizando"
    case done = "Hecho"
    case error = "Error"
}
