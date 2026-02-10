import Foundation
import NaturalLanguage

enum DocLanguage {
    case spanish
    case english
}

/// Detects the dominant language of a document using Apple's NaturalLanguage APIs.
struct LanguageDetector {
    /// Returns the dominant language constrained to Spanish or English.
    static func detect(from text: String) -> DocLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let language = recognizer.dominantLanguage
        return map(language)
    }

    /// Returns OCR recognition languages ordered by priority.
    static func recognitionLanguages(for language: DocLanguage) -> [String] {
        switch language {
        case .spanish:
            return ["es-ES", "en-US"]
        case .english:
            return ["en-US", "es-ES"]
        }
    }

    private static func map(_ language: NLLanguage?) -> DocLanguage {
        switch language {
        case .spanish:
            return .spanish
        case .english:
            return .english
        default:
            return .spanish
        }
    }
}
