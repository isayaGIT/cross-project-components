# AssetServer Protocol

This directory defines the AssetServer's language-independent resource management contract.

- `Definitions/asset-types.json` is the single source of truth for resource category IDs, labels, descriptions, and accepted media-type prefixes.
- `Schemas/asset-type-registry.schema.json` validates the registry document.
- The sample server exposes the registry at `GET /api/v1/protocols/asset-server` and the schema at `GET /api/v1/protocols/asset-server/1.0/schemas/asset-type-registry.schema.json`.

Interactive content document schemas (sticker packs, message bubbles, fullscreen animations, etc.) remain in `Protocols/InteractiveAssets/`; they describe content structures, not AssetServer library categories.

For interactive materials, Asset Manager uses the bundle upload contract in `Protocols/InteractiveAssets/README.md`; a material is one logical content document plus its complete file inventory, not a group of separately published files.
