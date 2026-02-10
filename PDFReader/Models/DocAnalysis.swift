import Foundation

/// Structured analysis generated for a document.
struct DocAnalysis: Codable, Hashable {
    var summary: String
    var category: DocCategory
    var tags: [String]
}

/// Allowed document categories.
enum DocCategory: String, Codable, CaseIterable, Hashable {
    case factura = "Factura"
    case contrato = "Contrato"
    case cv = "CV"
    case apuntes = "Apuntes"
    case email = "Email"
    case informe = "Informe"
    case otros = "Otros"
}
