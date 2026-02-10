import Foundation
import PDFKit
import CoreGraphics
import Vision

/// Extracts image-related notes when a page contains embedded images.
struct PDFImageExtractor {
    private let renderer = PDFPageRenderer()

    /// Returns true if the page contains at least one embedded image XObject.
    func pageHasImage(_ page: PDFPage) -> Bool {
        guard let pageRef = page.pageRef else { return false }
        return hasImageXObject(pageRef)
    }

    /// Extracts text-based descriptions for pages that contain images.
    func extractImages(
        from url: URL,
        recognitionLanguages: [String] = ["es-ES", "en-US"],
        language: DocLanguage,
        scale: CGFloat = 1.5
    ) async throws -> [PageImage] {
        guard let document = PDFDocument(url: url) else {
            return []
        }

        var results: [PageImage] = []
        let pageCount = document.pageCount

        for pageIndex in 0..<pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            guard pageHasImage(page) else { continue }

            guard let cgImage = renderer.render(page: page, scale: scale) else { continue }
            let labels = (try? await classifyImage(cgImage)) ?? []
            let description = await DocumentAnalyzer().interpretImageDescription(
                labels: labels,
                language: language,
                pageIndex: pageIndex,
                imageIndex: 0
            )
            results.append(PageImage(pageIndex: pageIndex, description: description))
        }

        return results
    }

    /// Classifies a rendered page image into semantic labels.
    private func classifyImage(_ image: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNClassificationObservation]) ?? []
                let labels = observations.prefix(6).map { $0.identifier }
                continuation.resume(returning: labels)
            }
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func hasImageXObject(_ page: CGPDFPage) -> Bool {
        guard let dict = page.dictionary else { return false }
        guard let resources = dictionary(dict, name: "Resources") else { return false }
        guard let xObjects = dictionary(resources, name: "XObject") else { return false }

        var found = false
        CGPDFDictionaryApplyFunction(xObjects, { _, object, info in
            guard let info else { return }
            let pointer = info.assumingMemoryBound(to: Bool.self)
            if pointer.pointee { return }

            if CGPDFObjectGetType(object) == .stream {
                var stream: CGPDFStreamRef?
                if CGPDFObjectGetValue(object, .stream, &stream), let stream {
                    if let streamDict = CGPDFStreamGetDictionary(stream) {
                        var subtype: UnsafePointer<Int8>?
                        if CGPDFDictionaryGetName(streamDict, "Subtype", &subtype),
                           let subtype,
                           String(cString: subtype) == "Image" {
                            pointer.pointee = true
                        }
                    }
                }
            }
        }, &found)

        return found
    }

    private func dictionary(_ parent: CGPDFDictionaryRef, name: String) -> CGPDFDictionaryRef? {
        var dict: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(parent, name, &dict) else { return nil }
        return dict
    }
}
