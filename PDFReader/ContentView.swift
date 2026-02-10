import SwiftUI
import UniformTypeIdentifiers

/// Root list view for imported documents.
struct ContentView: View {
    @StateObject private var viewModel = DocumentListViewModel()
    @State private var showingImporter = false

    /// Main list UI with import and search.
    var body: some View {
        NavigationStack {
            List {
                if viewModel.filteredItems.isEmpty, !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("No matches")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.filteredItems) { item in
                        NavigationLink(value: item.id) {
                            DocumentRowView(item: item)
                        }
                    }
                }
            }
            .navigationTitle("PDFAIReaderMVP")
            .searchable(text: $viewModel.searchQuery, prompt: "Buscar en resúmenes y tags")
            .onChange(of: viewModel.searchQuery) { _ in
                viewModel.updateSearchResults()
            }
            .toolbar {
                Button("Importar PDF") {
                    showingImporter = true
                }
                Button("Limpiar cache") {
                    viewModel.clearCache()
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    viewModel.importDocuments(urls: urls)
                case .failure:
                    break
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let item = viewModel.item(for: id) {
                    DocumentDetailView(item: item) {
                        viewModel.reprocess(item)
                    }
                } else {
                    Text("Documento no disponible")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
