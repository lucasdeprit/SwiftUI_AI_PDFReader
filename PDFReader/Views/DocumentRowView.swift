import SwiftUI

/// Row showing document title, status, and progress.
struct DocumentRowView: View {
    let item: DocumentItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                Text(item.status.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if item.status == .ocr || item.status == .analyzing {
                    ProgressView(value: item.progress)
                }
                if let error = item.errorMessage, item.status == .error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Spacer()
            if item.isCached {
                Text("cache")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}
