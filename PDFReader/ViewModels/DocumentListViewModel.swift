import Foundation
import Combine

/// Coordinates import, OCR, analysis, cache, and search.
@MainActor
final class DocumentListViewModel: ObservableObject {
    @Published private(set) var items: [DocumentItem] = []
    @Published var searchQuery: String = ""
    @Published private(set) var searchResults: [DocumentItem] = []

    private let ocrService = OCRService()
    private let analyzer = DocumentAnalyzer()
    private let cache = DocumentCache()
    private let searchService = SemanticSearchService()
    private var searchTask: Task<Void, Never>?

    var filteredItems: [DocumentItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? items : searchResults
    }

    /// Adds PDFs and starts processing immediately.
    func importDocuments(urls: [URL]) {
        for url in urls {
            addDocument(url)
        }
    }

    /// Returns the latest item snapshot for navigation.
    func item(for id: UUID) -> DocumentItem? {
        items.first(where: { $0.id == id })
    }

    /// Invalidates cache and reprocesses the document.
    func reprocess(_ item: DocumentItem) {
        Task {
            await cache.invalidate(for: item.url)
            await process(itemID: item.id, force: true)
        }
    }

    /// Clears all cached entries.
    func clearCache() {
        Task {
            await cache.clearAll()
            for index in items.indices {
                items[index].isCached = false
            }
        }
    }

    /// Recomputes semantic search results for the current query.
    func updateSearchResults() {
        searchTask?.cancel()
        let query = searchQuery
        let itemsSnapshot = items
        searchTask = Task { [searchService] in
            let results = await searchService.rank(query: query, items: itemsSnapshot)
            await MainActor.run {
                self.searchResults = results
            }
        }
    }

    private func addDocument(_ url: URL) {
        var item = DocumentItem(url: url, title: url.deletingPathExtension().lastPathComponent)
        item.status = .ocr
        items.insert(item, at: 0)
        searchResults = items
        Task {
            await process(itemID: item.id, force: false)
        }
    }

    private func process(itemID: UUID, force: Bool) async {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        let url = items[index].url
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if !force, let cached = await cache.load(for: url) {
            update(itemID: itemID) { item in
                item.ocrText = cached.ocrText
                item.analysis = cached.analysis
                item.status = .done
                item.progress = 1
                item.isCached = true
                item.errorMessage = nil
            }
            return
        }

        update(itemID: itemID) { item in
            item.status = .ocr
            item.progress = 0
            item.isCached = false
            item.errorMessage = nil
        }
        searchResults = items

        let (task, stream) = await ocrService.extractTextWithProgress(pdfURL: url, recognitionLanguages: ["es-ES", "en-US"], scale: 2.5)
        let progressTask = Task {
            for await value in stream {
                await MainActor.run {
                    self.update(itemID: itemID) { item in
                        item.progress = value
                    }
                }
            }
        }

        do {
            let ocrText = try await task.value
            progressTask.cancel()

            update(itemID: itemID) { item in
                item.ocrText = ocrText
                item.status = .analyzing
            }

            let language = LanguageDetector.detect(from: ocrText)
            let analysis = await analyzer.analyze(text: ocrText, language: language)

            update(itemID: itemID) { item in
                item.analysis = analysis
                item.status = .done
                item.progress = 1
            }
            updateSearchResults()

            await cache.save(CachedDocument(ocrText: ocrText, analysis: analysis), for: url)
        } catch {
            progressTask.cancel()
            update(itemID: itemID) { item in
                item.status = .error
                item.errorMessage = error.localizedDescription
            }
            updateSearchResults()
        }
    }

    private func update(itemID: UUID, _ updateBlock: (inout DocumentItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        var item = items[index]
        updateBlock(&item)
        items[index] = item
    }
}
