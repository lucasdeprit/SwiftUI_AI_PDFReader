import Foundation
import PDFKit
import UIKit

/// Renders a PDF page into a CGImage for OCR.
struct PDFPageRenderer {
    /// Renders a page at the requested scale with a white background.
    func render(page: PDFPage, scale: CGFloat = 2.5) -> CGImage? {
        let pageRect = page.bounds(for: .mediaBox)
        let width = Int(pageRect.width * scale)
        let height = Int(pageRect.height * scale)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        context.setFillColor(UIColor.white.cgColor)
        context.fill(pageRect)

        // Flip the context vertically to match PDF coordinate system.
        context.translateBy(x: 0, y: pageRect.height)
        context.scaleBy(x: 1, y: -1)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()

        return context.makeImage()
    }
}
