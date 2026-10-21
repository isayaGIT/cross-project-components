import SwiftUI
import MarkdownUI

/// A reusable, read-only GitHub-Flavored Markdown renderer for SwiftUI.
///
/// Markdown is supplied by the host application. The component does not own
/// persistence or editing state, so it can be embedded in any document viewer.
public struct MarkdownPreview: View {
    private let markdown: String
    private let baseURL: URL?
    private let imageBaseURL: URL?

    /// Creates a Markdown preview.
    ///
    /// - Parameters:
    ///   - markdown: The source Markdown text to render.
    ///   - baseURL: Optional base URL used to resolve relative links.
    ///   - imageBaseURL: Optional base URL used to resolve relative image URLs.
    public init(
        markdown: String,
        baseURL: URL? = nil,
        imageBaseURL: URL? = nil
    ) {
        self.markdown = markdown
        self.baseURL = baseURL
        self.imageBaseURL = imageBaseURL
    }

    public var body: some View {
        Markdown(markdown, baseURL: baseURL, imageBaseURL: imageBaseURL)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
