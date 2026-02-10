import Foundation

enum OCRServiceError: Error, LocalizedError {
    case openFailed
    case pageMissing(Int)
    case renderFailed(Int)
    case ocrFailed

    var errorDescription: String? {
        switch self {
        case .openFailed:
            return "No se pudo abrir el PDF."
        case .pageMissing(let index):
            return "No se pudo leer la página \(index + 1)."
        case .renderFailed(let index):
            return "No se pudo renderizar la página \(index + 1)."
        case .ocrFailed:
            return "Error durante el OCR."
        }
    }
}
