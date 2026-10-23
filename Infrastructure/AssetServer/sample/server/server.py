#!/usr/bin/env python3
"""Minimal single-app asset server: HTML upload UI + JSON manifest + file download."""
from __future__ import annotations

import hashlib
import json
import mimetypes
import os
import re
import uuid
import zipfile
import io
from datetime import datetime, timezone
from email.parser import BytesParser
from email.policy import default
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse, parse_qs

ROOT = Path(os.environ.get("ASSET_DATA_DIR", Path(__file__).parent / "data")).resolve()
FILES = ROOT / "files"
MANIFEST = ROOT / "manifest.json"
ASSET_PROTOCOL_DIR = Path(os.environ.get("ASSET_SERVER_PROTOCOL_DIR", Path(__file__).resolve().parents[2] / "Protocols")).resolve()
ASSET_TYPE_REGISTRY = ASSET_PROTOCOL_DIR / "Definitions" / "asset-types.json"
ASSET_PROTOCOL_SCHEMA_DIR = ASSET_PROTOCOL_DIR / "Schemas"
SCHEMA_DIR = Path(os.environ.get("INTERACTIVE_ASSET_SCHEMA_DIR", Path(__file__).resolve().parents[4] / "Protocols" / "InteractiveAssets" / "Schemas")).resolve()
PROTOCOL_VERSION = "1.0"
ASSET_SERVER_PROTOCOL_VERSION = "1.0"
CONTENT_SCHEMA_FILES = {
    "sticker-library": "sticker-library.schema.json",
    "sticker-pack": "sticker-pack.schema.json",
    "sticker": "sticker.schema.json",
    "animated-message-bubble": "animated-message-bubble.schema.json",
    "fullscreen-animation": "fullscreen-animation.schema.json",
}
APP_ID = os.environ.get("ASSET_APP_ID", "sample-app")
PORT = int(os.environ.get("PORT", "8080"))
# This catalog is the authoritative list of UI locations the server can control.
CONTROLLABLE_SLOTS = [
    {"slot": "chat.background", "label": "聊天背景", "description": "聊天消息后方显示的背景图", "accepts": ["image/"]},
    {"slot": "chat.header", "label": "聊天页头部装饰", "description": "聊天页面顶部区域使用的装饰图", "accepts": ["image/"]},
    {"slot": "chat.empty-state", "label": "空聊天页插画", "description": "开始聊天前显示的插画", "accepts": ["image/"]},
    {"slot": "profile.avatar.default", "label": "默认个人头像", "description": "个人资料没有自定义头像时使用的默认图片", "accepts": ["image/"]},
    {"slot": "app.launch-screen", "label": "应用启动页图片", "description": "应用启动时显示的图片", "accepts": ["image/"]},
]
SLOT_BY_ID = {item["slot"]: item for item in CONTROLLABLE_SLOTS}


def load_asset_type_registry() -> dict:
    if not ASSET_TYPE_REGISTRY.is_file():
        raise RuntimeError(f"Asset type registry is missing: {ASSET_TYPE_REGISTRY}")
    registry = json.loads(ASSET_TYPE_REGISTRY.read_text(encoding="utf-8"))
    types = registry.get("assetTypes")
    if not isinstance(types, list) or not types:
        raise RuntimeError("Asset type registry must define a non-empty assetTypes array")
    ids = [item.get("id") for item in types if isinstance(item, dict)]
    if len(ids) != len(types) or len(set(ids)) != len(ids) or any(not isinstance(value, str) or not value for value in ids):
        raise RuntimeError("Asset type registry contains invalid or duplicate IDs")
    return registry

def asset_categories() -> list[dict]:
    return load_asset_type_registry()["assetTypes"]

def asset_category_ids() -> set[str]:
    return {item["id"] for item in asset_categories()}
FILES.mkdir(parents=True, exist_ok=True)

HTML = (Path(__file__).with_name("index.html")).read_text(encoding="utf-8")


def load_manifest() -> dict:
    if not MANIFEST.exists():
        return {"schemaVersion": 1, "appId": APP_ID, "assets": [], "placements": [], "interactiveContent": []}
    try:
        data = json.loads(MANIFEST.read_text("utf-8"))
        if data.get("appId") != APP_ID:
            raise ValueError("Stored manifest appId does not match ASSET_APP_ID")
        data.setdefault("placements", [])
        data.setdefault("interactiveContent", [])
        return data
    except (json.JSONDecodeError, ValueError) as exc:
        raise RuntimeError(f"Cannot read manifest: {exc}") from exc


def save_manifest(data: dict) -> None:
    tmp = MANIFEST.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", "utf-8")
    tmp.replace(MANIFEST)


def load_schema(schema_name: str) -> dict:
    if schema_name not in CONTENT_SCHEMA_FILES:
        raise ValueError("Unsupported interactive content type")
    path = SCHEMA_DIR / CONTENT_SCHEMA_FILES[schema_name]
    if not path.is_file():
        raise RuntimeError(f"Protocol schema is missing: {path}")
    return json.loads(path.read_text("utf-8"))


def validate_content_document(content_type: str, document: dict) -> list[str]:
    try:
        from jsonschema import Draft202012Validator, FormatChecker
    except ImportError as exc:
        raise RuntimeError("JSON Schema validation requires the jsonschema package") from exc
    schema = load_schema(content_type)
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    errors = sorted(validator.iter_errors(document), key=lambda error: (list(map(str, error.absolute_path)), error.message))
    return [f"{'/'.join(map(str, error.absolute_path)) or '$'}: {error.message}" for error in errors]


def referenced_asset_ids(value) -> set[str]:
    found: set[str] = set()
    if isinstance(value, dict):
        asset_id = value.get("assetID")
        if isinstance(asset_id, str) and asset_id:
            found.add(asset_id)
        for child in value.values():
            found.update(referenced_asset_ids(child))
    elif isinstance(value, list):
        for child in value:
            found.update(referenced_asset_ids(child))
    return found


def content_id_for(content_type: str, document: dict) -> str:
    return str(document.get("id", "")).strip()


def validate_complete_fields(schema: dict, value, path: str = "$", errors: list[str] | None = None) -> list[str]:
    """Require every field declared in a protocol object's properties. Nullable optional fields must be explicit null in a future schema revision; current v1 schemas require concrete values."""
    errors = errors if errors is not None else []
    if not isinstance(value, dict):
        return errors
    properties = schema.get("properties", {})
    for key, child_schema in properties.items():
        if key not in value:
            errors.append(f"{path}.{key}: field declared by protocol is missing")
            continue
        child = value[key]
        if isinstance(child_schema, dict) and child is not None:
            if "$ref" in child_schema:
                ref = child_schema["$ref"].split("/")[-1]
                target = schema.get("$defs", {}).get(ref, {})
                validate_complete_fields(target, child, f"{path}.{key}", errors)
            elif child_schema.get("type") == "array" and isinstance(child, list):
                item_schema = child_schema.get("items", {})
                for index, item in enumerate(child):
                    if "$ref" in item_schema:
                        ref = item_schema["$ref"].split("/")[-1]
                        target = schema.get("$defs", {}).get(ref, {})
                        validate_complete_fields(target, item, f"{path}.{key}[{index}]", errors)
                    else:
                        validate_complete_fields(item_schema, item, f"{path}.{key}[{index}]", errors)
            else:
                validate_complete_fields(child_schema, child, f"{path}.{key}", errors)
    return errors


def content_type_category(content_type: str) -> str:
    if content_type in ("sticker", "sticker-pack", "sticker-library"):
        return "sticker"
    if content_type == "animated-message-bubble":
        return "bubble"
    if content_type == "fullscreen-animation":
        return "fullscreen"
    return "general"


class Handler(BaseHTTPRequestHandler):
    server_version = "AssetServerSample/0.1"

    def log_message(self, fmt, *args):
        print(f"[{self.log_date_time_string()}] {self.address_string()} {fmt % args}")

    def send_json(self, status: int, value: dict):
        body = json.dumps(value, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = unquote(urlparse(self.path).path)
        if path == "/" or path == "/index.html":
            body = HTML.encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if path == "/health":
            return self.send_json(200, {"ok": True})
        if path == "/api/v1/app":
            return self.send_json(200, {"appId": APP_ID})
        if path == "/api/v1/protocols/asset-server":
            try:
                registry = load_asset_type_registry()
                return self.send_json(200, {"protocolVersion": ASSET_SERVER_PROTOCOL_VERSION, "registrySchema": "/api/v1/protocols/asset-server/1.0/schemas/asset-type-registry.schema.json", "assetTypes": registry["assetTypes"]})
            except (OSError, json.JSONDecodeError, RuntimeError) as exc:
                return self.send_json(500, {"error": str(exc)})
        if path == "/api/v1/protocols/asset-server/1.0/schemas/asset-type-registry.schema.json":
            schema_path = ASSET_PROTOCOL_SCHEMA_DIR / "asset-type-registry.schema.json"
            if not schema_path.is_file():
                return self.send_json(404, {"error": "Asset Server protocol schema not found"})
            body = schema_path.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "application/schema+json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if path == "/api/v1/protocols/interactive-assets":
            return self.send_json(200, {"protocolVersion": PROTOCOL_VERSION, "schemaDialect": "https://json-schema.org/draft/2020-12/schema", "contentTypes": sorted(CONTENT_SCHEMA_FILES), "assetCategories": asset_categories(), "schemaFiles": {key: f"/api/v1/protocols/interactive-assets/{PROTOCOL_VERSION}/schemas/{filename}" for key, filename in CONTENT_SCHEMA_FILES.items()}, "manifestSchema": f"/api/v1/protocols/interactive-assets/{PROTOCOL_VERSION}/schemas/asset-manifest.schema.json"})
        schema_match = re.fullmatch(r"/api/v1/protocols/interactive-assets/1\.0/schemas/([a-z0-9-]+\.schema\.json)", path)
        if schema_match:
            schema_name = schema_match.group(1)
            if schema_name != "asset-manifest.schema.json" and schema_name not in CONTENT_SCHEMA_FILES.values():
                return self.send_json(404, {"error": "Unknown protocol schema"})
            schema_path = SCHEMA_DIR / schema_name
            if not schema_path.is_file():
                return self.send_json(404, {"error": "Protocol schema not found"})
            body = schema_path.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "application/schema+json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "public, max-age=300")
            self.end_headers()
            self.wfile.write(body)
            return
        content_collection = re.fullmatch(r"/api/v1/apps/([^/]+)/versions/([^/]+)/interactive-content", path)
        if content_collection:
            app_id, version = content_collection.groups()
            if app_id != APP_ID:
                return self.send_json(404, {"error": "Unknown app"})
            try:
                manifest = load_manifest()
            except RuntimeError as exc:
                return self.send_json(500, {"error": str(exc)})
            entries = [entry for entry in manifest["interactiveContent"] if entry["version"] == version]
            return self.send_json(200, {"protocolVersion": PROTOCOL_VERSION, "appId": APP_ID, "version": version, "items": [{"id": entry["id"], "type": entry["type"], "contentVersion": entry["contentVersion"], "publishedAt": entry["publishedAt"], "document": entry["document"]} for entry in entries]})
        content_item = re.fullmatch(r"/api/v1/apps/([^/]+)/versions/([^/]+)/interactive-content/([^/]+)", path)
        if content_item:
            app_id, version, content_id = content_item.groups()
            if app_id != APP_ID:
                return self.send_json(404, {"error": "Unknown app"})
            try:
                manifest = load_manifest()
            except RuntimeError as exc:
                return self.send_json(500, {"error": str(exc)})
            entry = next((item for item in manifest["interactiveContent"] if item["version"] == version and item["id"] == content_id), None)
            if not entry:
                return self.send_json(404, {"error": "Interactive content not found"})
            return self.send_json(200, {"protocolVersion": PROTOCOL_VERSION, "appId": APP_ID, "version": version, "id": entry["id"], "type": entry["type"], "contentVersion": entry["contentVersion"], "publishedAt": entry["publishedAt"], "document": entry["document"]})
        protocol_manifest = re.fullmatch(r"/api/v1/apps/([^/]+)/versions/([^/]+)/interactive-manifests/([^/]+)", path)
        if protocol_manifest:
            app_id, version, content_id = protocol_manifest.groups()
            if app_id != APP_ID:
                return self.send_json(404, {"error": "Unknown app"})
            try:
                manifest = load_manifest()
            except RuntimeError as exc:
                return self.send_json(500, {"error": str(exc)})
            entry = next((item for item in manifest["interactiveContent"] if item["version"] == version and item["id"] == content_id), None)
            if not entry:
                return self.send_json(404, {"error": "Interactive content not found"})
            ids = referenced_asset_ids(entry["document"])
            assets = [asset for asset in manifest["assets"] if asset["id"] in ids and version in asset["versions"]]
            files = [{"id": asset["id"], "fileName": Path(asset["name"]).name, "mediaType": asset["contentType"], "byteCount": asset["size"], "sha256": asset["sha256"], "role": asset.get("description") or asset["contentType"]} for asset in assets]
            logical = {"protocolVersion": PROTOCOL_VERSION, "contentID": content_id, "contentType": entry["type"], "contentVersion": entry["contentVersion"], "files": files}
            # The manifest schema is validated explicitly because it is not a content document type.
            try:
                from jsonschema import Draft202012Validator, FormatChecker
                schema = json.loads((SCHEMA_DIR / "asset-manifest.schema.json").read_text("utf-8"))
                errors = [error.message for error in Draft202012Validator(schema, format_checker=FormatChecker()).iter_errors(logical)]
            except (ImportError, OSError, json.JSONDecodeError) as exc:
                return self.send_json(500, {"error": f"Cannot validate generated asset manifest: {exc}"})
            if errors:
                return self.send_json(500, {"error": "Generated asset manifest failed schema validation", "details": errors})
            return self.send_json(200, logical)
        if path == "/api/v1/slots":
            version = parse_qs(urlparse(self.path).query).get("version", ["1.0.0"])[0]
            try:
                manifest = load_manifest()
            except RuntimeError as exc:
                return self.send_json(500, {"error": str(exc)})
            result = []
            for definition in CONTROLLABLE_SLOTS:
                item = dict(definition)
                placement = next((p for p in manifest["placements"] if p["slot"] == item["slot"] and p["version"] == version), None)
                if placement:
                    asset = next((a for a in manifest["assets"] if a["id"] == placement["assetId"] and version in a["versions"]), None)
                    if asset:
                        assigned = dict(asset)
                        assigned["downloadUrl"] = f"/api/v1/assets/{asset['id']}/download"
                        item["assignment"] = {"assetId": asset["id"], "asset": assigned, "updatedAt": placement.get("updatedAt")}
                    else:
                        item["assignment"] = None
                else:
                    item["assignment"] = None
                result.append(item)
            return self.send_json(200, {"schemaVersion": 1, "appId": APP_ID, "version": version, "slots": result})
        match = re.fullmatch(r"/api/v1/apps/([^/]+)/versions/([^/]+)/assets", path)
        if match:
            app_id, version = match.groups()
            if app_id != APP_ID:
                return self.send_json(404, {"error": "Unknown app"})
            try:
                manifest = load_manifest()
            except RuntimeError as exc:
                return self.send_json(500, {"error": str(exc)})
            assets = []
            for asset in manifest["assets"]:
                if version in asset["versions"]:
                    item = dict(asset)
                    item["downloadUrl"] = f"/api/v1/assets/{asset['id']}/download"
                    assets.append(item)
            return self.send_json(200, {"schemaVersion": 1, "appId": APP_ID, "version": version, "assets": assets})
        match = re.fullmatch(r"/api/v1/apps/([^/]+)/versions/([^/]+)/placements/(.+)", path)
        if match:
            app_id, version, slot = match.groups()
            slot = unquote(slot)
            if app_id != APP_ID:
                return self.send_json(404, {"error": "Unknown app"})
            try:
                manifest = load_manifest()
            except RuntimeError as exc:
                return self.send_json(500, {"error": str(exc)})
            placement = next((p for p in manifest["placements"] if p["slot"] == slot and p["version"] == version), None)
            if not placement:
                return self.send_json(404, {"error": "No asset is assigned to this display slot", "slot": slot, "version": version})
            asset = next((a for a in manifest["assets"] if a["id"] == placement["assetId"] and version in a["versions"]), None)
            if not asset:
                return self.send_json(404, {"error": "Assigned asset is missing or not part of this version"})
            item = dict(asset)
            item["downloadUrl"] = f"/api/v1/assets/{asset['id']}/download"
            return self.send_json(200, {"schemaVersion": 1, "appId": APP_ID, "version": version, "slot": slot, "asset": item})
        match = re.fullmatch(r"/api/v1/assets/([A-Za-z0-9._-]+)/download", path)
        if match:
            asset_id = match.group(1)
            try:
                asset = next((a for a in load_manifest()["assets"] if a["id"] == asset_id), None)
            except RuntimeError as exc:
                return self.send_json(500, {"error": str(exc)})
            if not asset:
                return self.send_json(404, {"error": "Asset not found"})
            file_path = FILES / asset["storedName"]
            if not file_path.is_file():
                return self.send_json(404, {"error": "Asset file missing"})
            self.send_response(200)
            self.send_header("Content-Type", asset["contentType"])
            self.send_header("Content-Length", str(file_path.stat().st_size))
            self.send_header("Content-Disposition", f'attachment; filename="{asset["name"].replace(chr(34), "")}"')
            self.send_header("ETag", '"' + asset["sha256"] + '"')
            self.end_headers()
            with file_path.open("rb") as f:
                while chunk := f.read(1024 * 256):
                    self.wfile.write(chunk)
            return
        self.send_json(404, {"error": "Not found"})

    def do_POST(self):
        parsed = urlparse(self.path)
        bundle_match = re.fullmatch(r"/api/v1/apps/([^/]+)/versions/([^/]+)/interactive-bundles", parsed.path)
        if bundle_match:
            app_id, version = bundle_match.groups()
            requested_category = parse_qs(parsed.query).get("category", [""])[0]
            if requested_category not in asset_category_ids() or requested_category in {"display", "general"}:
                return self.send_json(400, {"error": "A valid material category must be selected"})
            if app_id != APP_ID:
                return self.send_json(404, {"error": "Unknown app"})
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if length <= 0 or length > 100 * 1024 * 1024:
                    return self.send_json(413, {"error": "Bundle must be between 1 byte and 100 MB"})
                content_type_header = self.headers.get("Content-Type", "")
                if not content_type_header.lower().startswith("multipart/form-data;"):
                    return self.send_json(415, {"error": "Expected multipart/form-data with one ZIP bundle"})
                raw = self.rfile.read(length)
                message = BytesParser(policy=default).parsebytes((f"Content-Type: {content_type_header}\r\nMIME-Version: 1.0\r\n\r\n").encode() + raw)
                part = next((item for item in message.iter_parts() if item.get_param("name", header="content-disposition") == "bundle" and item.get_filename()), None)
                if part is None:
                    return self.send_json(400, {"error": "Upload exactly one material bundle ZIP as field 'bundle'"})
                archive_bytes = part.get_payload(decode=True) or b""
                with zipfile.ZipFile(io.BytesIO(archive_bytes)) as archive:
                    infos = [item for item in archive.infolist() if not item.is_dir()]
                    if len(infos) > 250:
                        return self.send_json(413, {"error": "Bundle may contain at most 250 files"})
                    names = [item.filename for item in infos]
                    if len(names) != len(set(names)) or any(name.startswith("/") or "\\" in name or any(piece in ("", ".", "..") for piece in name.split("/")) for name in names):
                        return self.send_json(422, {"error": "Bundle contains duplicate or unsafe paths"})
                    if sum(item.file_size for item in infos) > 100 * 1024 * 1024:
                        return self.send_json(413, {"error": "Expanded bundle exceeds 100 MB"})
                    if "content.json" not in names or "asset-manifest.json" not in names:
                        return self.send_json(422, {"error": "Bundle must contain content.json and asset-manifest.json"})
                    document = json.loads(archive.read("content.json"))
                    bundle_manifest = json.loads(archive.read("asset-manifest.json"))
                    if not isinstance(document, dict) or not isinstance(bundle_manifest, dict):
                        return self.send_json(422, {"error": "Content and asset manifest must be JSON objects"})
                    manifest_schema = json.loads((SCHEMA_DIR / "asset-manifest.schema.json").read_text("utf-8"))
                    from jsonschema import Draft202012Validator, FormatChecker
                    manifest_errors = sorted(Draft202012Validator(manifest_schema, format_checker=FormatChecker()).iter_errors(bundle_manifest), key=lambda e: list(map(str, e.absolute_path)))
                    manifest_completeness = validate_complete_fields(manifest_schema, bundle_manifest)
                    if manifest_errors or manifest_completeness:
                        return self.send_json(422, {"error": "Asset manifest is incomplete or failed JSON Schema validation", "details": [f"{'/'.join(map(str,e.absolute_path)) or '$'}: {e.message}" for e in manifest_errors] + manifest_completeness})
                    content_type = bundle_manifest["contentType"]
                    if content_type_category(content_type) != requested_category:
                        return self.send_json(422, {"error": f"Selected category {requested_category} does not match bundle category {content_type_category(content_type)}"})
                    content_errors = validate_content_document(content_type, document)
                    complete_errors = validate_complete_fields(load_schema(content_type), document)
                    if content_errors or complete_errors:
                        return self.send_json(422, {"error": "Content document is incomplete or invalid", "details": content_errors + complete_errors})
                    content_id = content_id_for(content_type, document)
                    content_version = str(document.get("version", "1"))
                    if bundle_manifest["protocolVersion"] != PROTOCOL_VERSION or bundle_manifest["contentID"] != content_id or bundle_manifest["contentVersion"] != content_version:
                        return self.send_json(422, {"error": "Bundle manifest identity/version does not match content.json"})
                    file_entries = bundle_manifest["files"]
                    file_ids = [item["id"] for item in file_entries]
                    file_names = [item["fileName"] for item in file_entries]
                    if len(file_ids) != len(set(file_ids)) or len(file_names) != len(set(file_names)):
                        return self.send_json(422, {"error": "Manifest file IDs and filenames must be unique"})
                    expected_paths = {"content.json", "asset-manifest.json"} | {"files/" + name for name in file_names}
                    if set(names) != expected_paths:
                        return self.send_json(422, {"error": "ZIP entries must exactly match manifest files under files/", "expected": sorted(expected_paths), "actual": sorted(names)})
                    staged = []
                    for item in file_entries:
                        data = archive.read("files/" + item["fileName"])
                        digest = hashlib.sha256(data).hexdigest()
                        if len(data) != item["byteCount"] or digest.lower() != item["sha256"].lower():
                            return self.send_json(422, {"error": "File integrity mismatch", "fileName": item["fileName"]})
                        staged.append((item, data, digest))
                    referenced = referenced_asset_ids(document)
                    if referenced != set(file_ids):
                        return self.send_json(422, {"error": "Manifest files must exactly match content asset references", "unreferencedFileIDs": sorted(set(file_ids)-referenced), "missingFileIDs": sorted(referenced-set(file_ids))})
                    manifest = load_manifest()
                    if any(entry["version"] == version and entry["id"] == content_id for entry in manifest["interactiveContent"]):
                        return self.send_json(409, {"error": "A material with this ID already exists in this version"})
                    existing_asset_ids = {asset["id"] for asset in manifest["assets"]}
                    if existing_asset_ids.intersection(file_ids):
                        return self.send_json(409, {"error": "Bundle asset IDs must not collide with existing assets", "assetIDs": sorted(existing_asset_ids.intersection(file_ids))})
                    created = []
                    now = datetime.now(timezone.utc).isoformat()
                    try:
                        for item, data, digest in staged:
                            asset_id = item["id"]
                            stored_name = str(uuid.uuid4()) + Path(item["fileName"]).suffix[:20]
                            (FILES / stored_name).write_bytes(data)
                            created.append(stored_name)
                            asset = {"id": asset_id, "name": item["fileName"], "description": item.get("role", ""), "contentType": item["mediaType"], "category": content_type_category(content_type), "size": len(data), "sha256": digest, "storedName": stored_name, "versions": [version], "createdAt": now}
                            manifest["assets"].append(asset)
                        manifest["interactiveContent"].append({"id": content_id, "type": content_type, "version": version, "contentVersion": content_version, "document": document, "publishedAt": now})
                        save_manifest(manifest)
                    except Exception:
                        for stored_name in created:
                            (FILES / stored_name).unlink(missing_ok=True)
                        raise
                    return self.send_json(201, {"ok": True, "id": content_id, "type": content_type, "contentVersion": content_version, "fileCount": len(staged), "publishedAt": now})
            except (ValueError, TypeError, RuntimeError, OSError, KeyError, zipfile.BadZipFile, json.JSONDecodeError) as exc:
                return self.send_json(400, {"error": f"Invalid material bundle: {exc}"})
        publish_match = re.fullmatch(r"/api/v1/apps/([^/]+)/versions/([^/]+)/interactive-content", parsed.path)
        if publish_match:
            app_id, version = publish_match.groups()
            if app_id != APP_ID:
                return self.send_json(404, {"error": "Unknown app"})
            if not version or len(version) > 100:
                return self.send_json(400, {"error": "Invalid version"})
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if length <= 0 or length > 1024 * 1024:
                    return self.send_json(413, {"error": "Interactive content JSON must be between 1 byte and 1 MB"})
                payload = json.loads(self.rfile.read(length))
                if not isinstance(payload, dict):
                    return self.send_json(400, {"error": "Content document must be a JSON object"})
                query = parse_qs(parsed.query)
                content_type = query.get("type", [""])[0].strip()
                if content_type not in CONTENT_SCHEMA_FILES:
                    return self.send_json(400, {"error": "Unsupported interactive content type", "allowedTypes": sorted(CONTENT_SCHEMA_FILES)})
                errors = validate_content_document(content_type, payload)
                if errors:
                    return self.send_json(422, {"error": "Content document failed JSON Schema validation", "details": errors})
                content_id = content_id_for(content_type, payload)
                if not content_id or len(content_id) > 200:
                    return self.send_json(422, {"error": "Content document has an invalid id"})
                manifest = load_manifest()
                asset_ids = referenced_asset_ids(payload)
                assets_by_id = {asset["id"]: asset for asset in manifest["assets"]}
                missing = sorted(asset_id for asset_id in asset_ids if asset_id not in assets_by_id or version not in assets_by_id[asset_id]["versions"])
                if missing:
                    return self.send_json(422, {"error": "Content document references assets that are not available in this version", "missingAssetIDs": missing})
                if content_type == "sticker-library":
                    published_pack_ids = {item["id"] for item in manifest["interactiveContent"] if item["version"] == version and item["type"] == "sticker-pack"}
                    missing_packs = sorted(set(payload.get("packIDs", [])) - published_pack_ids)
                    if missing_packs:
                        return self.send_json(422, {"error": "Sticker library references packs that are not published in this version", "missingPackIDs": missing_packs})
                now = datetime.now(timezone.utc).isoformat()
                entry = {"id": content_id, "type": content_type, "version": version,
                         "contentVersion": str(payload.get("version", "1")), "document": payload, "publishedAt": now}
                manifest["interactiveContent"] = [item for item in manifest["interactiveContent"] if not (item["version"] == version and item["id"] == content_id)]
                manifest["interactiveContent"].append(entry)
                save_manifest(manifest)
                return self.send_json(201, {"ok": True, "protocolVersion": PROTOCOL_VERSION, "id": content_id, "type": content_type, "version": version, "contentVersion": entry["contentVersion"], "publishedAt": now})
            except (ValueError, TypeError, RuntimeError, OSError) as exc:
                return self.send_json(400, {"error": f"Invalid interactive content: {exc}"})
        if parsed.path == "/api/v1/placements":
            try:
                length = int(self.headers.get("Content-Length", "0"))
                payload = json.loads(self.rfile.read(length))
                slot = str(payload.get("slot", "")).strip()
                asset_id = str(payload.get("assetId", "")).strip()
                version = parse_qs(parsed.query).get("version", ["1.0.0"])[0].strip()
                if slot not in SLOT_BY_ID:
                    return self.send_json(400, {"error": "Unknown display slot", "allowedSlots": list(SLOT_BY_ID)})
                manifest = load_manifest()
                asset = next((a for a in manifest["assets"] if a["id"] == asset_id), None)
                if not asset or version not in asset["versions"]:
                    return self.send_json(404, {"error": "Asset not found in this version"})
                if not any(asset["contentType"].startswith(prefix) for prefix in SLOT_BY_ID[slot]["accepts"]):
                    return self.send_json(415, {"error": "Asset type is not supported by this display location"})
                manifest["placements"] = [p for p in manifest["placements"] if not (p["slot"] == slot and p["version"] == version)]
                placement = {"slot": slot, "version": version, "assetId": asset_id, "updatedAt": datetime.now(timezone.utc).isoformat()}
                manifest["placements"].append(placement)
                save_manifest(manifest)
                return self.send_json(201, placement)
            except (ValueError, TypeError, RuntimeError) as exc:
                return self.send_json(400, {"error": f"Invalid placement: {exc}"})
        if parsed.path != "/api/v1/assets":
            return self.send_json(404, {"error": "Not found"})
        content_type = self.headers.get("Content-Type", "")
        if not content_type.lower().startswith("multipart/form-data;"):
            return self.send_json(415, {"error": "Expected multipart/form-data"})
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return self.send_json(400, {"error": "Invalid Content-Length"})
        if length <= 0 or length > 100 * 1024 * 1024:
            return self.send_json(413, {"error": "File upload must be between 1 byte and 100 MB"})
        raw = self.rfile.read(length)
        message = BytesParser(policy=default).parsebytes((f"Content-Type: {content_type}\r\nMIME-Version: 1.0\r\n\r\n").encode() + raw)
        uploaded = None
        for part in message.iter_parts():
            if part.get_param("name", header="content-disposition") == "file" and part.get_filename():
                uploaded = (Path(part.get_filename()).name, part.get_payload(decode=True) or b"")
                break
        if not uploaded or not uploaded[1]:
            return self.send_json(400, {"error": "Choose a non-empty file"})
        filename, content = uploaded
        query = urlparse(self.path).query
        version = parse_qs(query).get("version", ["1.0.0"])[0].strip()
        if not version or len(version) > 100:
            return self.send_json(400, {"error": "Invalid version"})
        asset_id = str(uuid.uuid4())
        digest = hashlib.sha256(content).hexdigest()
        suffix = Path(filename).suffix[:20]
        stored_name = asset_id + suffix
        (FILES / stored_name).write_bytes(content)
        content_type = mimetypes.guess_type(filename)[0] or "application/octet-stream"
        try:
            manifest = load_manifest()
            default_category = "display" if parse_qs(query).get("slot", [""])[0].strip() else "general"
            category = parse_qs(query).get("category", [default_category])[0].strip() or default_category
            allowed_categories = asset_category_ids()
            if category not in allowed_categories:
                raise ValueError("Unknown asset category: " + category)
            asset = {"id": asset_id, "name": filename, "description": "", "contentType": content_type,
                     "category": category, "size": len(content), "sha256": digest, "storedName": stored_name,
                     "versions": [version], "createdAt": datetime.now(timezone.utc).isoformat()}
            manifest["assets"].append(asset)
            slot = parse_qs(query).get("slot", [""])[0].strip()
            if slot:
                if slot not in SLOT_BY_ID:
                    raise ValueError("Unknown display slot: " + slot)
                if not any(content_type.startswith(prefix) for prefix in SLOT_BY_ID[slot]["accepts"]):
                    raise ValueError("Asset type is not supported by display slot: " + slot)
                manifest["placements"] = [p for p in manifest["placements"] if not (p["slot"] == slot and p["version"] == version)]
                manifest["placements"].append({"slot": slot, "version": version, "assetId": asset_id,
                                                "updatedAt": datetime.now(timezone.utc).isoformat()})
            save_manifest(manifest)
        except Exception as exc:
            (FILES / stored_name).unlink(missing_ok=True)
            return self.send_json(500, {"error": f"Could not save asset metadata: {exc}"})
        result = dict(asset)
        result["downloadUrl"] = f"/api/v1/assets/{asset_id}/download"
        self.send_json(201, result)


    def do_DELETE(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/v1/placements":
            query = parse_qs(parsed.query)
            version = query.get("version", ["1.0.0"])[0].strip()
            slot = query.get("slot", [""])[0].strip()
            if slot not in SLOT_BY_ID or not version:
                return self.send_json(400, {"error": "A valid version and known display slot are required"})
            try:
                manifest = load_manifest()
                before = len(manifest["placements"])
                manifest["placements"] = [p for p in manifest["placements"] if not (p["slot"] == slot and p["version"] == version)]
                if len(manifest["placements"]) == before:
                    return self.send_json(404, {"error": "No assignment exists for this display slot and version"})
                save_manifest(manifest)
                return self.send_json(200, {"ok": True, "slot": slot, "version": version, "assignment": None})
            except (ValueError, TypeError, RuntimeError) as exc:
                return self.send_json(500, {"error": f"Could not clear placement: {exc}"})

        match = re.fullmatch(r"/api/v1/assets/([A-Za-z0-9._-]+)", parsed.path)
        if match:
            asset_id = match.group(1)
            try:
                manifest = load_manifest()
                asset = next((a for a in manifest["assets"] if a["id"] == asset_id), None)
                if not asset:
                    return self.send_json(404, {"error": "Asset not found"})
                manifest["assets"] = [a for a in manifest["assets"] if a["id"] != asset_id]
                manifest["placements"] = [p for p in manifest["placements"] if p["assetId"] != asset_id]
                manifest.setdefault("interactiveContent", [])
                manifest["interactiveContent"] = [entry for entry in manifest["interactiveContent"] if asset_id not in referenced_asset_ids(entry.get("document", {}))]
                remaining_content = manifest["interactiveContent"]
                manifest["interactiveContent"] = [entry for entry in remaining_content if entry["type"] != "sticker-library" or set(entry.get("document", {}).get("packIDs", [])) <= {pack["id"] for pack in remaining_content if pack["type"] == "sticker-pack" and pack["version"] == entry["version"]}]
                save_manifest(manifest)
                (FILES / asset["storedName"]).unlink(missing_ok=True)
                return self.send_json(200, {"ok": True, "deletedAssetId": asset_id, "removedAssignments": True})
            except (ValueError, TypeError, RuntimeError, OSError) as exc:
                return self.send_json(500, {"error": f"Could not delete asset: {exc}"})
        return self.send_json(404, {"error": "Not found"})


def main():
    print(f"AssetServer app={APP_ID} port={PORT} data={ROOT}")
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
