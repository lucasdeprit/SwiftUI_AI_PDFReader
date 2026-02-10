import Foundation
import CoreGraphics
import PDFKit
import Vision

/// Extracts text from PDFs using Vision OCR.
actor OCRService {
    private let renderer = PDFPageRenderer()

    /// Returns a task that performs OCR and a progress stream from 0 to 1.
    func extractTextWithProgress(
        pdfURL: URL,
        recognitionLanguages: [String] = ["es-ES", "en-US"],
        scale: CGFloat = 2.5
    ) -> (Task<String, Error>, AsyncStream<Double>) {
        var streamContinuation: AsyncStream<Double>.Continuation!
        let stream = AsyncStream<Double> { continuation in
            streamContinuation = continuation
        }

        let task = Task<String, Error> {
            guard let document = PDFDocument(url: pdfURL) else {
                streamContinuation.finish()
                throw OCRServiceError.openFailed
            }

            let pageCount = document.pageCount
            var pagesText: [String] = []
            pagesText.reserveCapacity(pageCount)

            for index in 0..<pageCount {
                if Task.isCancelled { throw CancellationError() }

                guard let page = document.page(at: index) else {
                    streamContinuation.finish()
                    throw OCRServiceError.pageMissing(index)
                }

                if let embedded = page.string?.trimmingCharacters(in: .whitespacesAndNewlines), !embedded.isEmpty {
                    pagesText.append(embedded)
                } else {
                    guard let image = renderer.render(page: page, scale: scale) else {
                        streamContinuation.finish()
                        throw OCRServiceError.renderFailed(index)
                    }

                    let text = try await recognizeText(in: image, recognitionLanguages: recognitionLanguages)
                    pagesText.append(text)
                }

                let progress = Double(index + 1) / Double(max(pageCount, 1))
                streamContinuation.yield(progress)
            }

            streamContinuation.finish()
            return pagesText.joined(separator: "\n\n")
        }

        streamContinuation.onTermination = { _ in
            task.cancel()
        }

        return (task, stream)
    }

    private func recognizeText(in image: CGImage, recognitionLanguages: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRServiceError.ocrFailed)
                    return
                }

                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = recognitionLanguages

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

    /// Performs OCR on a rendered image (used for image preview descriptions).
    func extractText(from image: CGImage, recognitionLanguages: [String]) async throws -> String {
        try await recognizeText(in: image, recognitionLanguages: recognitionLanguages)
    }
}
