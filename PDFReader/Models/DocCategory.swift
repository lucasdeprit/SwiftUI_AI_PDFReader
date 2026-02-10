import Foundation

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
