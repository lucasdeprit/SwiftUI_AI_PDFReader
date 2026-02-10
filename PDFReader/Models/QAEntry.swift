import Foundation

struct QAEntry: Identifiable, Hashable {
    let id = UUID()
    let question: String
    let answer: String
}
