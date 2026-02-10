import Foundation
import FoundationModels
import NaturalLanguage

/// Generates summary, category, and tags using Foundation Models.
final class DocumentAnalyzer {
    private let maxChunkChars = 8000
    private let chunkSize = 6000

    /// Analyzes a document; uses chunking for long inputs.
    func analyze(text: String, language: DocLanguage) async -> DocAnalysis {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty {
            return DocAnalysis(summary: "Sin contenido detectable.", category: .otros, tags: [])
        }
        if cleaned.count > maxChunkChars {
            return await analyzeWithChunking(text: cleaned, language: language)
        }

        return await analyzeSingle(text: cleaned, language: language)
    }

    /// Summarizes in chunks and then generates a meta-summary.
    private func analyzeWithChunking(text: String, language: DocLanguage) async -> DocAnalysis {
        let chunks = chunkText(text, maxLength: chunkSize)
        var chunkSummaries: [String] = []

        for chunk in chunks {
            let analysis = await analyzeSingle(text: chunk, language: language)
            chunkSummaries.append(analysis.summary)
        }

        let combined = chunkSummaries.joined(separator: "\n")
        let metaAnalysis = await analyzeSingle(text: combined, language: language)

        return DocAnalysis(summary: metaAnalysis.summary, category: metaAnalysis.category, tags: metaAnalysis.tags)
    }

    /// Runs a single Foundation Models request.
    private func analyzeSingle(text: String, language: DocLanguage) async -> DocAnalysis {
        if let analysis = try? await FoundationModelsAnalyzer.analyze(text: text, language: language) {
            return analysis
        }
        return DocAnalysis(summary: "Error de análisis.", category: .otros, tags: [])
    }

    /// Generates a natural language interpretation for an image using Foundation Models.
    func interpretImageDescription(labels: [String], language: DocLanguage, pageIndex: Int, imageIndex: Int) async -> String {
        let safeLabels = labels
        let prompt: String
        switch language {
        case .spanish:
            prompt = safeLabels.isEmpty ? """
            No hay etiquetas detectadas. Devuelve exactamente en este formato:
            \"Pagina \(pageIndex + 1), imagen \(imageIndex + 1) interpretación: No disponible.\"
            """ : """
            Genera una descripcion breve y concreta de lo que muestra una imagen.
            Etiquetas detectadas: \(safeLabels.joined(separator: ", ")).
            Devuelve exactamente en este formato:
            \"Pagina \(pageIndex + 1), imagen \(imageIndex + 1) interpretación: <descripcion>\"
            """
        case .english:
            prompt = safeLabels.isEmpty ? """
            No labels detected. Return exactly in this format:
            \"Page \(pageIndex + 1), image \(imageIndex + 1) interpretation: Not available.\"
            """ : """
            Generate a concise description of what an image shows.
            Detected labels: \(safeLabels.joined(separator: ", ")).
            Return exactly in this format:
            \"Page \(pageIndex + 1), image \(imageIndex + 1) interpretation: <description>\"
            """
        }

        let session = LanguageModelSession()
        if let response = try? await session.respond(to: prompt) {
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return language == .spanish
            ? "Pagina \(pageIndex + 1), imagen \(imageIndex + 1) interpretación: No disponible."
            : "Page \(pageIndex + 1), image \(imageIndex + 1) interpretation: Not available."
    }

    /// Answers a user question about the document using Foundation Models.
    func answerQuestion(text: String, question: String, language: DocLanguage) async throws -> String {
        let cleanedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuestion.isEmpty else {
            return language == .spanish ? "Pregunta vacia." : "Empty question."
        }

        let context = selectRelevantContext(question: cleanedQuestion, text: text, language: language)

        let prompt: String
        switch language {
        case .spanish:
            prompt = """
            Responde a la pregunta usando solo el contenido del documento.
            Si no esta en el texto, di que no se encuentra en el documento.

            Documento:
            \(context)

            Pregunta:
            \(cleanedQuestion)
            """
        case .english:
            prompt = """
            Answer the question using only the document content.
            If the answer is not in the text, say it is not found in the document.

            Document:
            \(context)

            Question:
            \(cleanedQuestion)
            """
        }

        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func chunkText(_ text: String, maxLength: Int) -> [String] {
        var chunks: [String] = []
        var current = ""
        for paragraph in text.components(separatedBy: "\n") {
            if current.count + paragraph.count + 1 > maxLength {
                if !current.isEmpty {
                    chunks.append(current)
                    current = ""
                }
            }
            current.append(paragraph)
            current.append("\n")
        }
        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks.isEmpty ? [text] : chunks
    }

    /// Selects top-ranked chunks to keep the model within context limits.
    private func selectRelevantContext(question: String, text: String, language: DocLanguage) -> String {
        let maxContext = 9000
        guard text.count > maxContext else { return text }

        let chunks = chunkText(text, maxLength: 2500)
        let nlLanguage: NLLanguage = (language == .spanish) ? .spanish : .english
        let embedding = NLEmbedding.sentenceEmbedding(for: nlLanguage) ?? NLEmbedding.sentenceEmbedding(for: .english)
        guard let embedding, let qVec = embedding.vector(for: question) else {
            return String(text.prefix(maxContext))
        }

        let scored = chunks.compactMap { chunk -> (String, Double)? in
            guard let cVec = embedding.vector(for: chunk) else { return nil }
            let score = cosineSimilarity(qVec, cVec)
            return (chunk, score)
        }
        let top = scored.sorted { $0.1 > $1.1 }.prefix(3).map { $0.0 }
        let context = top.joined(separator: "\n---\n")
        return context.count > maxContext ? String(context.prefix(maxContext)) : context
    }

    /// Cosine similarity helper for embeddings.
    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        let count = min(a.count, b.count)
        guard count > 0 else { return -1 }
        var dot = 0.0
        var normA = 0.0
        var normB = 0.0
        for i in 0..<count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = (sqrt(normA) * sqrt(normB))
        guard denom > 0 else { return -1 }
        return dot / denom
    }
}

private enum FoundationModelsAnalyzer {
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
