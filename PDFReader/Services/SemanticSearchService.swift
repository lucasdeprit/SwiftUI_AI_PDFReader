import Foundation
import NaturalLanguage

/// Ranks documents using on-device sentence embeddings from NaturalLanguage.
struct SemanticSearchService {
    /// Returns items sorted by semantic similarity with a minimum similarity threshold.
    func rank(query: String, items: [DocumentItem], minSimilarity: Double = 0.32, minFuzzyScore: Double = 0.82) async -> [DocumentItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        let language = map(recognizer.dominantLanguage)

        let embedding = NLEmbedding.sentenceEmbedding(for: language) ?? NLEmbedding.sentenceEmbedding(for: .english)
        guard let embedding else { return [] }
        guard let queryVector = embedding.vector(for: trimmed) else { return [] }

        let queryTokens = tokenize(trimmed)

        var scored: [(DocumentItem, Double)] = []
        scored.reserveCapacity(items.count)

        for item in items {
            guard let analysis = item.analysis else { continue }

            let searchable = [analysis.summary, analysis.tags.joined(separator: " "), analysis.category.rawValue]
                .joined(separator: " ")
            guard let docVector = embedding.vector(for: searchable) else { continue }

            let similarity = cosineSimilarity(queryVector, docVector)
            let fuzzyScore = fuzzyMatchScore(queryTokens: queryTokens, documentText: searchable)
            if similarity >= minSimilarity || fuzzyScore >= minFuzzyScore {
                let combinedScore = max(similarity, fuzzyScore)
                scored.append((item, combinedScore))
            }
        }

        return scored.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    private func map(_ language: NLLanguage?) -> NLLanguage {
        switch language {
        case .spanish:
            return .spanish
        case .english:
            return .english
        default:
            return .spanish
        }
    }

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

    private func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
    }

    private func fuzzyMatchScore(queryTokens: [String], documentText: String) -> Double {
        let docTokens = tokenize(documentText)
        guard !queryTokens.isEmpty, !docTokens.isEmpty else { return -1 }

        var bestScores: [Double] = []
        bestScores.reserveCapacity(queryTokens.count)

        for q in queryTokens {
            var best = 0.0
            for d in docTokens {
                let score = normalizedLevenshtein(a: q, b: d)
                if score > best { best = score }
                if best > 0.92 { break }
            }
            bestScores.append(best)
        }

        let sum = bestScores.reduce(0, +)
        return sum / Double(bestScores.count)
    }

    private func normalizedLevenshtein(a: String, b: String) -> Double {
        let distance = levenshtein(a, b)
        let maxLen = max(a.count, b.count)
        guard maxLen > 0 else { return 1 }
        return 1.0 - (Double(distance) / Double(maxLen))
    }

    private func levenshtein(_ a: String, _ b: String) -> Int {
        if a == b { return 0 }
        let aChars = Array(a)
        let bChars = Array(b)
        let aCount = aChars.count
        let bCount = bChars.count
        if aCount == 0 { return bCount }
        if bCount == 0 { return aCount }

        var prev = Array(0...bCount)
        var curr = Array(repeating: 0, count: bCount + 1)

        for i in 1...aCount {
            curr[0] = i
            for j in 1...bCount {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,
                    curr[j - 1] + 1,
                    prev[j - 1] + cost
                )
            }
            prev = curr
        }
        return prev[bCount]
    }
}
