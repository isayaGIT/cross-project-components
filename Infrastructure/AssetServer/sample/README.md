# AssetServer — minimal server + iOS sample

This sample demonstrates a server-driven asset flow: the server exposes an authoritative catalog of controllable UI locations, the HTML admin page lists every location and lets an operator assign an uploaded asset to it, and the iOS app requests the semantic location (for example, `chat.background`). The server resolves the current mapping; the app downloads, SHA-256 verifies, stores and displays the selected image as persistent application data (not in the evictable `Library/Caches` directory). Asset IDs are not hard-coded in the app.

## Layout

- `server/server.py` — Python HTTP server, HTML admin page, placement/download APIs, and InteractiveAssets Protocol publishing/validation APIs.
- `server/requirements.txt` — JSON Schema Draft 2020-12 validator dependency.
- `../../../../Protocols/InteractiveAssets/Schemas/` — shared protocol schemas used by local server runs and the container image.
- `server/Dockerfile` — container image suitable for a Sealos Deployment.
- `ios/AssetServerClient.swift` — reusable API/download client.
- `ios/ContentView.swift` — minimal SwiftUI screen demonstrating the client.
- `ios/AssetServerSampleApp.swift` — SwiftUI app entry point for the demo target.
- `ios/project.yml` — XcodeGen project definition; generates `ios/AssetServerSample.xcodeproj`.
- `tests/test_server.py` — server tests for health, slot catalog, assignment validation, upload, manifest, and download.

## Run locally

Requires Python 3.11+ and the dependency in `server/requirements.txt`. Install it with `python3 -m pip install -r Infrastructure/AssetServer/sample/server/requirements.txt`.

```bash
cd Infrastructure/AssetServer/sample/server
ASSET_APP_ID=sample-app ASSET_DATA_DIR="$PWD/data" PORT=8080 python3 server.py
```

Open `http://localhost:8080`, upload a PNG/JPEG, assign it to version `1.0.0`, and leave the display slot as `chat.background`. The asset library shows each file’s `assetID`. In **Publish interactive content**, choose a content type, load its template, replace placeholder IDs with uploaded asset IDs, and click **Validate & publish**. The server reports schema and cross-reference errors without publishing invalid documents. This upload both saves the asset and maps that display slot to it. The corresponding manifest endpoint is:

```text
GET http://localhost:8080/api/v1/apps/sample-app/versions/1.0.0/assets
```

Files download from the relative `downloadUrl` returned in each manifest entry. `GET /health` is intended for deployment health checks. To resolve a UI location, use `GET /api/v1/apps/{appId}/versions/{version}/placements/{slot}`; the response includes the server-selected asset metadata. To reassign a slot without re-uploading, `POST /api/v1/placements?version=1.0.0` with JSON `{ "slot": "chat.background", "assetId": "<asset-id>" }`.

## Sealos deployment outline

1. From the repository root, build the image with `docker build -f Infrastructure/AssetServer/sample/server/Dockerfile -t assetserver-sample:latest .` and push it to a registry available to your Sealos cluster.
2. Create a Deployment using that image, set container port `8080`, and expose it through a Sealos public ingress/domain.
3. **Mount persistent storage at `/data`**. The container's default `ASSET_DATA_DIR` is `/data`; without a persistent volume, uploaded files can disappear when the container is replaced.
4. Set `ASSET_APP_ID` to a stable ID for this server (default `sample-app`). Keep the same ID across restarts when reusing the same data volume.
5. Open the public HTTPS URL in a browser to upload a test asset. Configure that same base URL in the iOS sample.

This demo deliberately has **no authentication, authorization, rate limiting, or production-grade upload controls**. Do not expose it publicly with real/private assets until authentication is added. It is intended for testing only. Use HTTPS for public deployments.

## Add the iOS sample to Xcode

1. Install XcodeGen (`brew install xcodegen`) if needed.
2. Run `cd Infrastructure/AssetServer/sample/ios && xcodegen generate` to create the standalone `AssetServerSample.xcodeproj`.
3. Build/run the `AssetServerSample` scheme. In the iOS Simulator on the same Mac as the server, use `http://127.0.0.1:8080`; on a physical phone, use a reachable LAN address or the Sealos public HTTPS URL.
4. Keep the display slot set to `chat.background` and tap **Resolve & display background**. The sample also performs this sync automatically when it opens. The app syncs the complete slot catalog for the selected version, reuses existing files only after SHA-256 verification, and stores assets plus a local manifest under `Library/Application Support/AssetServer/Assets/`. A separate protocol panel fetches published content and its generated asset manifest, decodes supported content into the shared `InteractiveAssets` Swift models, and checks protocol identity, unique file IDs, safe leaf filenames, SHA-256 metadata shape, and exact agreement between referenced `assetID`s and manifest file IDs. This validates document structure and references; it does not yet download all protocol assets or render stickers, animated bubbles, or fullscreen animations. After a successful authoritative sync, it removes files no longer referenced by any assigned slot for that version. If the server is temporarily unavailable, it can display the last successfully synced persistent asset; once a successful sync reports no assignment, the old mapping and unused file are removed. Use PNG/JPEG for the native-image demo.

For local HTTP development, iOS App Transport Security may block cleartext traffic. Prefer HTTPS; if you temporarily enable local HTTP for testing, keep that exception development-only.

## API sketch

- `GET /api/v1/app` — returns this server's App ID.
- `GET /api/v1/apps/{appId}/versions/{version}/assets` — returns the asset manifest for that version.
- `GET /api/v1/slots?version={version}` — lists every server-supported display location, its accepted content types, and the asset currently assigned for that version.
- `GET /api/v1/apps/{appId}/versions/{version}/placements/{slot}` — resolves the server-owned mapping from a UI slot to an asset.
- `POST /api/v1/placements?version={version}` — assigns an existing compatible asset to a catalog display location using JSON `{ "slot": "chat.background", "assetId": "<asset-id>" }`. Unknown slots and incompatible media types are rejected.
- `POST /api/v1/assets?version={version}&slot={slot}` — multipart upload with a `file` field; optional `slot` assigns the new asset immediately.
- `GET /api/v1/assets/{assetId}/download` — downloads the raw file.
- `GET /api/v1/protocols/interactive-assets` — protocol version, supported types, and schema endpoints.
- `GET /api/v1/protocols/interactive-assets/1.0/schemas/{schemaFile}` — fetches a published JSON Schema.
- `POST /api/v1/apps/{appId}/versions/{version}/interactive-content?type={contentType}` — validates and publishes a JSON document. The request body is the document itself, not a multipart upload.
- `GET /api/v1/apps/{appId}/versions/{version}/interactive-content` — lists published documents for a version.
- `GET /api/v1/apps/{appId}/versions/{version}/interactive-content/{contentId}` — fetches one published document.
- `GET /api/v1/apps/{appId}/versions/{version}/interactive-manifests/{contentId}` — generates a protocol manifest with only that document’s referenced files.
- `DELETE /api/v1/placements?version={version}&slot={slot}` — clears one version-specific display assignment.
- `DELETE /api/v1/assets/{assetId}` — deletes the asset from the server and removes all server-side placements that reference it.

The transport manifest contains asset ID, name, MIME type, size, SHA-256, version membership, and a relative download URL. The new InteractiveAssets protocol API exposes Draft 2020-12 schemas, accepts published content JSON, validates the document against its type schema, checks every `assetID` against assets available in the selected version, and returns a generated protocol asset manifest for the referenced files. Published documents are stored in the existing JSON manifest under `interactiveContent`; publishing the same ID again in the same version replaces that publication. Sticker-library entries are additionally checked against sticker packs already published in that version. This sample uses JSON metadata and local filesystem storage to keep the mechanics visible. The iOS demo requests the semantic slot name, but does not know or hard-code the asset ID. It is not yet the full AssetServer described in `readme-asset-server`: richer media previews, version management UI, authentication, and persistent database/object-storage adapters remain out of scope.

## Test

From the repository root, install the server test dependency and run the suite:

```bash
python3 -m pip install -r Infrastructure/AssetServer/sample/server/requirements.txt
python3 -m unittest discover -s Infrastructure/AssetServer/sample/tests -v
swift test --package-path Protocols/InteractiveAssets
```
