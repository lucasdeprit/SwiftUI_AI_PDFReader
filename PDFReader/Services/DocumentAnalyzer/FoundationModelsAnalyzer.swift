import Foundation
import FoundationModels

enum FoundationModelsAnalyzer {
    @Generable
    struct Output {
        @Guide(description: "Summary in 5-7 lines")
        var summary: String

        @Guide(description: "Category must be one of: Factura, Contrato, CV, Apuntes, Email, Informe, Otros")
        var category: String

        @Guide(description: "3-8 tags in lowercase")
        var tags: [String]
    }

    static func analyze(text: String, language: DocLanguage) async throws -> DocAnalysis {
        let session = LanguageModelSession()
        let prompt = buildPrompt(text: text, language: language)
        let response = try await session.respond(to: prompt, generating: Output.self)
        let output = response.content

        let normalized = output.category.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let category = DocCategory.allCases.first { $0.rawValue.lowercased() == normalized.lowercased() } ?? .otros
        let tags = output.tags.map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased() }
        return DocAnalysis(summary: output.summary, category: category, tags: tags)
    }

    private static func buildPrompt(text: String, language: DocLanguage) -> String {
        switch language {
        case .spanish:
            return "Analiza el siguiente documento y devuelve un resumen de 5-7 lineas, categoria y tags.\n\n\(text)"
        case .english:
            return "Analyze the following document and return a 5-7 line summary, category and tags.\n\n\(text)"
        }
    }
}
