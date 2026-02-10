import SwiftUI
import PDFKit
import UIKit

/// Detail screen with analysis and OCR text.
struct DocumentDetailView: View {
    let item: DocumentItem
    let onReprocess: () -> Void

    @State private var showOCR = false
    @State private var showImages = false
    @State private var pageImages: [PageImage] = []
    @State private var isLoadingImages = false
    @State private var imageError: String?
    @State private var previewImage: UIImage?
    @State private var hasImageCandidates = false
    @State private var questionText: String = ""
    @State private var answers: [QAEntry] = []
    @State private var isAsking = false
    @State private var answerError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                statusSection
                analysisSection
                toggleSection
                if showOCR {
                    ocrSection
                }
                qaSection
                imagesToggleSection
                if showImages {
                    imagesSection
                }
            }
            .padding()
        }
        .navigationTitle(item.title)
        .toolbar {
            if item.status == .done {
                Button("Reprocesar") {
                    onReprocess()
                }
            }
        }
        .task {
            await loadPreview()
            await detectImageCandidates()
        }
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 88)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("PDF")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Estado: \(item.status.rawValue)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if item.status == .ocr || item.status == .analyzing {
                ProgressView(value: item.progress)
            }
            if let error = item.errorMessage, item.status == .error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
    }

    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categoría")
                .font(.headline)
            Text(item.analysis?.category.rawValue ?? "-")
                .font(.body)

            Text("Resumen")
                .font(.headline)
            Text(item.analysis?.summary ?? "-")
                .font(.body)

            Text("Tags")
                .font(.headline)
            if let tags = item.analysis?.tags, !tags.isEmpty {
                WrapTagsView(tags: tags)
            } else {
                Text("-")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var toggleSection: some View {
        Toggle(isOn: $showOCR) {
            Text("Ver texto OCR")
        }
    }

    private var imagesToggleSection: some View {
        Group {
            if item.status == .done && hasImageCandidates {
                Toggle(isOn: $showImages) {
                    Text("Ver imágenes")
                }
                .onChange(of: showImages) { _, newValue in
                    if newValue {
                        Task { await loadImagesIfNeeded() }
                    }
                }
            }
        }
    }

    private var imagesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoadingImages {
                ProgressView("Buscando imágenes...")
            } else if let imageError {
                Text(imageError)
                    .foregroundStyle(.red)
            } else if pageImages.isEmpty {
                Text("No images detected.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(pageImages) { page in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(page.description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var ocrSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Texto completo")
                .font(.headline)
            Text(item.ocrText ?? "-")
                .textSelection(.enabled)
                .font(.body.monospaced())
        }
    }

    /// Q&A panel that uses Foundation Models over OCR text.
    private var qaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preguntas sobre el texto")
                .font(.headline)
            if (item.ocrText ?? "").isEmpty {
                Text("No hay texto OCR disponible para responder preguntas.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                TextField("Escribe tu pregunta", text: $questionText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button(isAsking ? "..." : "Preguntar") {
                    Task { await askQuestion() }
                }
                .disabled(isAsking || (item.ocrText ?? "").isEmpty || questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let answerError {
                Text(answerError)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
            ForEach(answers) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    Text("Q: \(entry.question)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(entry.answer)
                        .font(.body)
                }
                .padding(.vertical, 6)
            }
        }
    }

    private func loadPreview() async {
        guard previewImage == nil else { return }
        let url = item.url
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else { return }
        let thumbnail = page.thumbnail(of: CGSize(width: 128, height: 176), for: .mediaBox)
        await MainActor.run {
            previewImage = thumbnail
        }
    }

    private func loadImagesIfNeeded() async {
        guard pageImages.isEmpty, !isLoadingImages else { return }
        isLoadingImages = true
        imageError = nil

        let url = item.url
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        do {
            let languages = LanguageDetector.recognitionLanguages(for: LanguageDetector.detect(from: item.ocrText ?? ""))
            let language = LanguageDetector.detect(from: item.ocrText ?? "")
            let images = try await PDFImageExtractor().extractImages(
                from: url,
                recognitionLanguages: languages,
                language: language,
                scale: 1.5
            )
            await MainActor.run {
                self.pageImages = images
                self.isLoadingImages = false
            }
        } catch {
            await MainActor.run {
                self.imageError = error.localizedDescription
                self.isLoadingImages = false
            }
        }
    }

    private func detectImageCandidates() async {
        let url = item.url
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        guard let document = PDFDocument(url: url) else { return }
        var found = false
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            if PDFImageExtractor().pageHasImage(page) {
                found = true
                break
            }
        }
        await MainActor.run {
            hasImageCandidates = found
        }
    }

    private func askQuestion() async {
        guard !isAsking else { return }
        isAsking = true
        answerError = nil
        let question = questionText
        questionText = ""

        guard let text = item.ocrText, !text.isEmpty else {
            await MainActor.run {
                answerError = "No hay texto OCR disponible."
                isAsking = false
            }
            return
        }

        let language = LanguageDetector.detect(from: text)
        do {
            let answer = try await DocumentAnalyzer().answerQuestion(text: text, question: question, language: language)
            await MainActor.run {
                answers.insert(QAEntry(question: question, answer: answer), at: 0)
                isAsking = false
            }
        } catch {
            await MainActor.run {
                answerError = error.localizedDescription
                isAsking = false
            }
        }
    }
}

private struct QAEntry: Identifiable, Hashable {
    let id = UUID()
    let question: String
    let answer: String
}

private struct WrapTagsView: View {
    let tags: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
    }
}
