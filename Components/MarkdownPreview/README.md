# MarkdownPreview

A reusable SwiftUI view for displaying GitHub-Flavored Markdown in native macOS interfaces. Rendering is provided by [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) (MIT).

## Supported content

Headings, paragraphs, emphasis, inline and fenced code, links, images, ordered and unordered lists, task lists, blockquotes, tables, and thematic breaks.

## Usage

    import CrossProjectComponents

    MarkdownPreview(markdown: source)

Relative links and images can be resolved against a document location:

    MarkdownPreview(
        markdown: source,
        baseURL: documentURL,
        imageBaseURL: documentURL
    )

## Contract

- Read-only renderer: the host owns document editing, state, storage, and save behavior.
- Native SwiftUI view with selectable text.
- Optional base URLs support relative Markdown links and images.
- Uses MarkdownUI's system-adaptive rendering; host applications can place the component in their own layout and scroll view.
