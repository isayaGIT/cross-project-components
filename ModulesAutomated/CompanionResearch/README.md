# CompanionResearch

Native Swift port of the backend companion-research and image-discovery services in `cloud/services/companion_enrich.py`, `cloud/services/web_search.py`, `cloud/services/xiaohongshu.py`, and `cloud/services/image_search.py`. This module contains no UI code.

## Architecture

- `ResearchModels.swift` defines normalized search results, intent, search payloads, enrichment metadata, Xiaohongshu status, image candidates, and typed errors.
- `ResearchHTTP.swift` provides the injectable async HTTP transport, bounded response reads, request helpers, JSON helpers, and environment-backed configuration.
- `XiaohongshuClient.swift` implements MCP REST status checks, bearer authentication, feed normalization, search, cover URL extraction, and image candidate selection.
- `WebSearchService.swift` implements bias scoring, search-mode resolution, Serper, Wikipedia, DuckDuckGo Instant Answer and Lite fallback search, Xiaohongshu routing, deduplication, and prompt formatting.
- `CompanionEnricher.swift` implements skip and fast-path heuristics, LLM intent parsing, query execution, digest synthesis, and the final contextual block.
- `ImageSearchService.swift` implements feature gating, MCP readiness checks, safe URL validation through an injected callback, bounded image retrieval, image-type verification through an injected callback, and file persistence.

## Configuration

`ResearchConfiguration.environment()` reads `SERPER_API_KEY`, `XHS_MCP_BASE_URL`, `XHS_MCP_AUTH_TOKEN`, and `IMAGE_SEARCH_DISABLED`. The default Xiaohongshu MCP URL is `http://127.0.0.1:18060`, matching the Python service. Credentials are not embedded in source. Inject an explicit configuration in production, especially when running in a server/container where loopback does not point to the MCP host.

The HTTP transport is a `ResearchHTTPTransport`. `URLSessionResearchTransport` is the default implementation. Response and image size limits are configurable. Image downloads require an injected SSRF-aware URL checker and image MIME/type detector; this deliberately does not pretend a scheme check alone is sufficient SSRF protection. `LocalResearchFileStore` writes atomically beneath the caller-provided directory and rejects path-containing filenames.

## Public API

- `WebSearchService.search(_:maxResults:mode:)` returns normalized `[ResearchResult]`. Modes are `auto`, `xiaohongshu`, `web`, and `both`.
- `WebSearchService.inferSearchBias(_:)`, `resolveSearchModes(query:mode:)`, and `formatResultsForPrompt(_:results:)` expose reusable routing and formatting behavior.
- `XiaohongshuClient.status()`, `searchFeeds(_:maxResults:)`, and `searchImageCandidates(_:maxResults:preferImageNotes:)` expose the MCP integration.
- `CompanionEnricher.run(...)` executes intent detection, search, and optional digest synthesis. LLM integration is supplied as async throwing closures; the callbacks can wrap the application's existing LLM gateway without introducing an unverified gateway signature into this package.
- `ImageSearchService.searchAndDownload(query:saveDirectory:maxCandidates:)` returns a structured success/error value rather than throwing provider failures to the caller.

## Example

```swift
let configuration = ResearchConfiguration.environment()
let transport = URLSessionResearchTransport()
let search = WebSearchService(configuration: configuration, transport: transport)
let enricher = CompanionEnricher(searchService: search)

let result = await enricher.run(
    userMessage: "最近想去探店，有什么值得推荐的咖啡馆？",
    recentDialog: "",
    memoryHints: "",
    isPrivate: true,
    searchEnabled: true,
    llmJSONCall: { prompt in
        // Call the application's JSON-mode LLM gateway here.
        return try await applicationLLMJSON(prompt)
    },
    llmDigestCall: { prompt in
        // Optional: use a low-cost model to produce concise internal notes.
        return try await applicationLLMDigest(prompt)
    }
)

if !result.contextBlock.isEmpty {
    // Add the returned context block to the downstream server-side prompt.
}
```

The example's `applicationLLMJSON` and `applicationLLMDigest` are placeholders for app-owned adapter functions, not APIs provided by this module.

## Behavioral notes and limitations

Search and Xiaohongshu failures degrade to empty results or structured metadata rather than crashing the enrichment flow. The original source's intent and digest system prompts are represented through the prompt-building behavior, but the LLM adapter owns model selection and system-message construction; the callbacks here receive the constructed user prompt. `parseIntentJSON` accepts JSON objects and fenced or surrounding text, caps queries at two, and fills missing source hints with `auto`.

DuckDuckGo Lite is HTML-based and can change its markup; it is a best-effort fallback. Wikipedia is attempted in Chinese and then English. Serper is optional and skipped when no key is configured. Xiaohongshu functionality requires a separately running, logged-in MCP service.

The source Python code returns dictionaries with camelCase metadata and can call synchronous provider functions. This Swift port provides typed values and async APIs instead; callers crossing a JSON boundary can encode the `Codable` models. Provider ordering, basic routing, feed fields, context formatting, and download result semantics are retained, but Python's exact dictionary shape and exception text are not guaranteed byte-for-byte identical.

Image safety depends on the injected `isSafeURL` implementation to reject private, loopback, link-local, redirect-to-private, and otherwise disallowed destinations. The supplied HTTP transport follows URLSession redirect behavior; deployments requiring strict SSRF protection should use a transport that validates every redirect target or disables redirects. The injected detector should validate actual image signatures, not trust file extensions or response headers alone.

No app-specific credentials, filesystem paths, UI code, tests, or invented server endpoints are included.