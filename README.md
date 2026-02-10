# PDFAIReaderMVP

PDFAIReaderMVP is a SwiftUI universal iPhone/iPad app that imports PDFs, performs on-device OCR, and generates structured analysis using Foundation Models. It also supports semantic search and question answering over the extracted text.

## Requirements
- Xcode 26 or newer
- iOS 26 deployment target
- Apple Intelligence enabled (assumed available)

## Tech Stack
- SwiftUI for UI and navigation
- PDFKit for PDF loading and rendering
- Vision for OCR and image classification
- FoundationModels for analysis and Q&A
- NaturalLanguage for language detection and semantic retrieval

## Architecture Overview

**Models**
- `DocumentItem`: PDF + processing state + OCR + analysis.
- `DocAnalysis`: summary/category/tags.
- `PageImage`: per-page image interpretation note.

**Services**
- `PDFPageRenderer`: renders a `PDFPage` to `CGImage` for OCR/classification.
- `OCRService`: actor that extracts text page-by-page with progress.
- `DocumentAnalyzer`: uses Foundation Models for summary/category/tags and Q&A.
- `DocumentCache`: optional JSON cache keyed by PDF hash.
- `PDFImageExtractor`: detects pages with embedded images and generates text-only interpretations using Vision + Foundation Models.
- `SemanticSearchService`: semantic ranking using sentence embeddings + fuzzy fallback.

**ViewModels**
- `DocumentListViewModel`: import orchestration, OCR progress, analysis, cache, and search.

**Views**
- `ContentView`: list, search, import, and cache clearing.
- `DocumentDetailView`: analysis, OCR toggle, Q&A, and image interpretation section.

## Data Flow
1. Import PDFs with `fileImporter`.
2. OCR extracts text per page and updates progress.
3. Foundation Models generates summary/category/tags.
4. Results cached by PDF hash.
5. Search uses semantic similarity against summaries/tags.
6. Q&A retrieves relevant text chunks and answers via Foundation Models.
7. Image section detects embedded image pages and generates text interpretations.

## Services Behavior

**OCRService**
- Uses `VNRecognizeTextRequest` with accurate recognition.
- Prefers embedded text if available on a page.
- Emits progress via `AsyncStream<Double>`.

**DocumentAnalyzer**
- `analyze(text:)` produces summary/category/tags.
- `answerQuestion(text:question:)` uses semantic chunk retrieval to stay within model context limits.
- `interpretImageDescription(labels:)` produces page/image descriptions from Vision labels.

**PDFImageExtractor**
- Detects embedded image XObjects in PDF resources.
- Renders the page and classifies with `VNClassifyImageRequest`.
- Generates a text-only description via Foundation Models.

**SemanticSearchService**
- Uses `NLEmbedding.sentenceEmbedding` for semantic similarity.
- Adds fuzzy matching to handle typos (e.g., "curiculum").
- Returns only matches above a threshold.

## Notes
- Everything runs on-device. No servers.
- Large PDFs are handled with chunked context retrieval for Q&A.
- Image extraction is text-only (no image display) by design.
