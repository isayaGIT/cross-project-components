# Large image test fixture

- File: `large-landscape.jpg`
- Dimensions: 3648 × 5472 pixels (portrait; 19.96 megapixels)
- Encoded size: approximately 2.1 MiB
- Format: progressive JPEG
- Source: Unsplash image CDN, photo ID `photo-1500530855697-b586d89ba3ee`
- Source URL: https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=max&w=6000&q=90
- Retrieval date: 2026-10-22

The image endpoint returned a 3648 × 5472 progressive JPEG despite the requested maximum width. A matching 426 × 640 preview is available as `large-landscape-preview.jpg` (about 60 KiB). Use the pair for repeatable preview/original comparisons, local decode, downsampling, and memory profiling; use the live URL in the showcase for network loading and preview-to-original behavior.
