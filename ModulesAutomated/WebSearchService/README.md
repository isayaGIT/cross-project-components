# WebSearchService

A reusable, Foundation-only Swift search-provider subsystem migrated from `cloud/services/web_search.py` and `cloud/services/xiaohongshu.py`. It intentionally remains a provider-layer module; it does not duplicate the higher-level intent classification, LLM synthesis, or image-download workflow in the existing `CompanionResearch` module.

## Public API

- `WebSearchService(configuration:transport:)` constructs an injectable provider client.
- `search(_:maxResults:mode:)` returns normalized `WebSearchResult` values. Modes are `auto`, `xiaohongshu`, `web`, and `both`.
- `inferSearchBias(_:)`, `resolveSearchModes(query:mode:)`, and `formatResultsForPrompt(_:results:)` expose source-compatible routing and prompt formatting.
- `WebSearchConfiguration.environment()` reads `SERPER_API_KEY`, `XHS_MCP_BASE_URL`, and `XHS_MCP_AUTH_TOKEN`.
- `xiaohongshuStatus()` checks MCP health and login status without exposing the token.
- `searchImageCandidates(_:maxResults:preferImageNotes:)` extracts cover candidates and defers video notes when image notes are preferred.
- `WebSearchHTTPTransport` permits deterministic test doubles and alternative transports.

## Provider order and compatibility

Web providers are attempted in order: optional Serper, Chinese Wikipedia, English Wikipedia, DuckDuckGo Instant Answer, then DuckDuckGo Lite. A failed or empty provider falls through to the next provider. Xiaohongshu results preserve the `title`, `snippet`, `url`, and `source` shape; search results use `source = "xiaohongshu"` or `"web"`. De-duplication follows the source's first-40-title/first-60-snippet key. Explicit `both` mode collects from both source groups, subject to the requested result cap.

The source's regex-based DuckDuckGo Lite parser is retained as a best-effort compatibility parser; markup changes can reduce recall. Feed normalization is intentionally limited to fields consumed by the source service.

## Security and reliability

- Provider destinations are fixed HTTPS endpoints. Xiaohongshu base URLs reject userinfo, query, fragment, and non-HTTP(S) schemes; cleartext HTTP is allowed only for loopback hosts, matching the local default while avoiding bearer-token transmission to remote plaintext endpoints.
- Credentials are injected via configuration and sent only to their provider endpoint. Error descriptions avoid returning response bodies that might contain sensitive upstream content.
- Request timeouts and maximum accepted response sizes are configurable and clamped to practical bounds. The default `URLSession` transport checks size after `data(for:)` buffers the response; strict memory-bounded deployments should inject a streaming transport that aborts when the byte cap is reached.
- Failures are deliberately converted to empty provider results so fallback can continue. The current public API does not expose per-provider diagnostics; add an injected observer if operational visibility is required.

## Open-source research and license decisions

- Xiaohongshu MCP API contract: [xpzouying/xiaohongshu-mcp](https://github.com/xpzouying/xiaohongshu-mcp), whose repository declares Apache-2.0. The implementation uses the documented REST shape and adapts it to Foundation types; it does not copy upstream source code. The repository shows ongoing releases; review the linked API documentation when upgrading the MCP server because endpoints and feed schemas can evolve.
- Networking architecture: [Apple URLSession documentation](https://developer.apple.com/documentation/foundation/urlsession). The implementation uses Foundation's async URLSession API behind an injectable protocol, without third-party dependencies.
- Serper request shape: [Serper integration documentation](https://github.com/serre-ai/research/blob/main/docs/integrations/serper.md) was consulted as a secondary reference for the HTTPS endpoint, `X-API-KEY` header, and JSON request format; no code from that repository is copied. The Serper service's own terms and quotas govern API use.

No third-party source code is vendored, so no upstream copyright notice is required beyond these references. The existing `CompanionResearch` subsystem remains the recommended orchestration integration; this module can be adopted independently where only provider-level search is needed.
