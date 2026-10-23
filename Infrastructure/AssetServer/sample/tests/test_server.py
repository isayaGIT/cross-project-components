import hashlib
import io
import zipfile
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.error
import urllib.request
from pathlib import Path

SERVER = Path(__file__).parents[1] / "server" / "server.py"


class AssetServerSmokeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.port = 18763
        env = os.environ.copy()
        env.update(PORT=str(cls.port), ASSET_APP_ID="test-app", ASSET_DATA_DIR=cls.temp.name)
        cls.proc = subprocess.Popen([sys.executable, str(SERVER)], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        cls.base = f"http://127.0.0.1:{cls.port}"
        for _ in range(50):
            try:
                urllib.request.urlopen(cls.base + "/health", timeout=0.2).read()
                break
            except Exception:
                time.sleep(0.1)
        else:
            raise RuntimeError("AssetServer failed to start")

    @classmethod
    def tearDownClass(cls):
        cls.proc.terminate()
        cls.proc.wait(timeout=5)
        cls.temp.cleanup()

    def test_health_and_app_id(self):
        self.assertEqual(json.loads(urllib.request.urlopen(self.base + "/health").read()), {"ok": True})
        self.assertEqual(json.loads(urllib.request.urlopen(self.base + "/api/v1/app").read())["appId"], "test-app")

    def test_controllable_slot_catalog(self):
        data = json.loads(urllib.request.urlopen(self.base + "/api/v1/slots?version=1.0.0").read())
        slots = {item["slot"]: item for item in data["slots"]}
        self.assertIn("chat.background", slots)
        self.assertIn("profile.avatar.default", slots)
        self.assertIsNone(slots["chat.background"]["assignment"])
        self.assertTrue(slots["chat.background"]["accepts"])

    def test_upload_manifest_and_download(self):
        boundary = "----asset-server-test-boundary"
        content = b"sample asset bytes\x00\x01"
        parts = [
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"version\"\r\n\r\n1.0.0\r\n".encode(),
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"sample.png\"\r\nContent-Type: image/png\r\n\r\n".encode(),
            content,
            f"\r\n--{boundary}--\r\n".encode(),
        ]
        request = urllib.request.Request(self.base + "/api/v1/assets?version=1.0.0&slot=chat.background", data=b"".join(parts), headers={"Content-Type": f"multipart/form-data; boundary={boundary}"}, method="POST")
        uploaded = json.loads(urllib.request.urlopen(request).read())
        self.assertEqual(uploaded["sha256"], hashlib.sha256(content).hexdigest())
        manifest_url = self.base + "/api/v1/apps/test-app/versions/1.0.0/assets"
        manifest = json.loads(urllib.request.urlopen(manifest_url).read())
        self.assertGreaterEqual(len(manifest["assets"]), 1)
        self.assertIn(uploaded["id"], [asset["id"] for asset in manifest["assets"]])
        downloaded = urllib.request.urlopen(self.base + uploaded["downloadUrl"]).read()
        self.assertEqual(downloaded, content)
        placement_url = self.base + "/api/v1/apps/test-app/versions/1.0.0/placements/chat.background"
        placement = json.loads(urllib.request.urlopen(placement_url).read())
        self.assertEqual(placement["slot"], "chat.background")
        self.assertEqual(placement["asset"]["id"], uploaded["id"])

    def test_placement_can_be_reassigned(self):
        boundary = "----asset-server-placement-boundary"
        content = b"replacement image bytes"
        body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"background.png\"\r\nContent-Type: image/png\r\n\r\n".encode()
                + content + f"\r\n--{boundary}--\r\n".encode())
        request = urllib.request.Request(self.base + "/api/v1/assets?version=1.0.0", data=body,
            headers={"Content-Type": f"multipart/form-data; boundary={boundary}"}, method="POST")
        asset = json.loads(urllib.request.urlopen(request).read())
        placement_request = urllib.request.Request(self.base + "/api/v1/placements?version=1.0.0",
            data=json.dumps({"slot": "chat.background", "assetId": asset["id"]}).encode(),
            headers={"Content-Type": "application/json"}, method="POST")
        urllib.request.urlopen(placement_request).read()
        resolved = json.loads(urllib.request.urlopen(self.base + "/api/v1/apps/test-app/versions/1.0.0/placements/chat.background").read())
        self.assertEqual(resolved["asset"]["id"], asset["id"])
        catalog = json.loads(urllib.request.urlopen(self.base + "/api/v1/slots?version=1.0.0").read())
        background = next(item for item in catalog["slots"] if item["slot"] == "chat.background")
        self.assertEqual(background["assignment"]["assetId"], asset["id"])


    def test_clear_assignment_and_delete_asset(self):
        boundary = "----asset-server-delete-boundary"
        content = b"asset to delete"
        body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"delete-me.png\"\r\nContent-Type: image/png\r\n\r\n".encode()
                + content + f"\r\n--{boundary}--\r\n".encode())
        request = urllib.request.Request(self.base + "/api/v1/assets?version=1.0.0&slot=chat.background", data=body,
            headers={"Content-Type": f"multipart/form-data; boundary={boundary}"}, method="POST")
        asset = json.loads(urllib.request.urlopen(request).read())

        clear = urllib.request.Request(self.base + "/api/v1/placements?version=1.0.0&slot=chat.background", method="DELETE")
        cleared = json.loads(urllib.request.urlopen(clear).read())
        self.assertIsNone(cleared["assignment"])
        slots = json.loads(urllib.request.urlopen(self.base + "/api/v1/slots?version=1.0.0").read())
        self.assertIsNone(next(item for item in slots["slots"] if item["slot"] == "chat.background")["assignment"])

        delete = urllib.request.Request(self.base + "/api/v1/assets/" + asset["id"], method="DELETE")
        result = json.loads(urllib.request.urlopen(delete).read())
        self.assertTrue(result["ok"])
        with self.assertRaises(urllib.error.HTTPError) as error:
            urllib.request.urlopen(self.base + asset["downloadUrl"])
        self.assertEqual(error.exception.code, 404)

    def test_asset_server_type_registry_protocol(self):
        registry = json.loads(urllib.request.urlopen(self.base + "/api/v1/protocols/asset-server").read())
        ids = [item["id"] for item in registry["assetTypes"]]
        self.assertEqual(ids, ["display", "sticker", "bubble", "fullscreen", "general"])
        schema = json.loads(urllib.request.urlopen(self.base + registry["registrySchema"]).read())
        self.assertEqual(schema["$schema"], "https://json-schema.org/draft/2020-12/schema")

    def test_protocol_discovery_and_schema_endpoints(self):
        discovery = json.loads(urllib.request.urlopen(self.base + "/api/v1/protocols/interactive-assets").read())
        self.assertEqual(discovery["protocolVersion"], "1.0")
        self.assertIn("animated-message-bubble", discovery["contentTypes"])
        schema = urllib.request.urlopen(self.base + discovery["schemaFiles"]["animated-message-bubble"]).read()
        self.assertEqual(json.loads(schema)["$schema"], "https://json-schema.org/draft/2020-12/schema")

    def _upload_test_asset(self, filename="bubble.gif", content=b"GIF89a test bytes", version="1.0.0"):
        boundary = "----interactive-content-upload-boundary"
        body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{filename}\"\r\nContent-Type: application/octet-stream\r\n\r\n".encode()
                + content + f"\r\n--{boundary}--\r\n".encode())
        request = urllib.request.Request(self.base + "/api/v1/assets?version=" + version, data=body,
            headers={"Content-Type": f"multipart/form-data; boundary={boundary}"}, method="POST")
        return json.loads(urllib.request.urlopen(request).read())

    def _publish_content(self, content_type, document, version="1.0.0"):
        request = urllib.request.Request(self.base + f"/api/v1/apps/test-app/versions/{version}/interactive-content?type={content_type}",
            data=json.dumps(document).encode(), headers={"Content-Type": "application/json"}, method="POST")
        return urllib.request.urlopen(request)

    def test_publish_validate_and_retrieve_animated_bubble(self):
        asset = self._upload_test_asset()
        document = {
            "protocolVersion": "1.0", "id": "bubble.test", "version": "1",
            "renderer": "gif", "decorations": [],
            "layout": {"cornerRadius": 18, "paddingTop": 12, "paddingLeading": 16, "paddingBottom": 12, "paddingTrailing": 16},
            "background": {"assetID": asset["id"], "role": "bubble-background"}
        }
        published = json.loads(self._publish_content("animated-message-bubble", document).read())
        self.assertEqual(published["id"], "bubble.test")
        content_url = self.base + "/api/v1/apps/test-app/versions/1.0.0/interactive-content/bubble.test"
        fetched = json.loads(urllib.request.urlopen(content_url).read())
        self.assertEqual(fetched["document"], document)
        protocol_manifest = json.loads(urllib.request.urlopen(self.base + "/api/v1/apps/test-app/versions/1.0.0/interactive-manifests/bubble.test").read())
        self.assertEqual(protocol_manifest["contentType"], "animated-message-bubble")
        self.assertEqual(protocol_manifest["files"][0]["id"], asset["id"])
        self.assertEqual(protocol_manifest["files"][0]["sha256"], asset["sha256"])

    def test_invalid_schema_and_missing_asset_reference_are_rejected(self):
        invalid = {"protocolVersion": "1.0", "id": "bad", "version": "1", "renderer": "magic-code", "decorations": [],
                   "layout": {"cornerRadius": -1, "paddingTop": 0, "paddingLeading": 0, "paddingBottom": 0, "paddingTrailing": 0}}
        with self.assertRaises(urllib.error.HTTPError) as error:
            self._publish_content("animated-message-bubble", invalid)
        self.assertEqual(error.exception.code, 422)
        self.assertIn("JSON Schema validation", json.loads(error.exception.read())["error"])

        missing_ref = {"protocolVersion": "1.0", "id": "missing-ref", "version": "1", "renderer": "gif", "decorations": [],
                       "layout": {"cornerRadius": 12, "paddingTop": 8, "paddingLeading": 8, "paddingBottom": 8, "paddingTrailing": 8},
                       "background": {"assetID": "does-not-exist"}}
        with self.assertRaises(urllib.error.HTTPError) as error:
            self._publish_content("animated-message-bubble", missing_ref)
        self.assertEqual(error.exception.code, 422)
        self.assertEqual(json.loads(error.exception.read())["missingAssetIDs"], ["does-not-exist"])

    def test_sticker_library_requires_published_packs(self):
        library = {"protocolVersion": "1.0", "id": "library", "name": "Library", "version": "1", "packIDs": ["not-published"]}
        with self.assertRaises(urllib.error.HTTPError) as error:
            self._publish_content("sticker-library", library)
        self.assertEqual(error.exception.code, 422)
        self.assertIn("missingPackIDs", json.loads(error.exception.read()))
        asset = self._upload_test_asset(filename="cat.gif")
        pack = {"protocolVersion": "1.0", "id": "cat-pack", "name": "Cats", "version": "2",
                "stickers": [{"id": "cat-wave", "media": {"assetID": asset["id"]}}]}
        self._publish_content("sticker-pack", pack).read()
        valid_library = {"protocolVersion": "1.0", "id": "community-library", "name": "Community", "version": "1", "packIDs": ["cat-pack"]}
        self._publish_content("sticker-library", valid_library).read()
        protocol_manifest = json.loads(urllib.request.urlopen(self.base + "/api/v1/apps/test-app/versions/1.0.0/interactive-manifests/community-library").read())
        self.assertEqual(protocol_manifest["files"], [])
        listing = json.loads(urllib.request.urlopen(self.base + "/api/v1/apps/test-app/versions/1.0.0/interactive-content").read())
        self.assertTrue({"cat-pack", "community-library"}.issubset({item["id"] for item in listing["items"]}))

    def _post_material_bundle(self, document, filename="bubble.gif", data=b"GIF89a bundle bytes", category="bubble"):
        asset_id = document.get("background", {}).get("assetID", "bubble-background")
        bundle_manifest = {"protocolVersion": "1.0", "contentID": document["id"], "contentType": "animated-message-bubble", "contentVersion": document["version"], "minimumClientVersion": "1.0", "metadataFileID": "content-metadata", "files": [{"id": asset_id, "fileName": filename, "mediaType": "image/gif", "byteCount": len(data), "sha256": hashlib.sha256(data).hexdigest(), "role": "background"}]}
        archive = io.BytesIO()
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
            z.writestr("content.json", json.dumps(document))
            z.writestr("asset-manifest.json", json.dumps(bundle_manifest))
            z.writestr("files/" + filename, data)
        boundary = "----material-bundle-test-boundary"
        body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"bundle\"; filename=\"material.zip\"\r\nContent-Type: application/zip\r\n\r\n".encode() + archive.getvalue() + f"\r\n--{boundary}--\r\n".encode())
        request = urllib.request.Request(self.base + "/api/v1/apps/test-app/versions/1.0.0/interactive-bundles?category={category}".format(category=category), data=body, headers={"Content-Type": f"multipart/form-data; boundary={boundary}"}, method="POST")
        return urllib.request.urlopen(request)

    def test_material_bundle_is_published_as_one_logical_item(self):
        document = {"protocolVersion": "1.0", "id": "bundle-bubble", "version": "1", "renderer": "gif", "background": {"assetID": "bundle-background", "role": "background-frame"}, "decorations": [], "layout": {"cornerRadius": 12, "paddingTop": 8, "paddingLeading": 8, "paddingBottom": 8, "paddingTrailing": 8}, "parameters": {"assetID": "bundle-background", "role": "renderer-parameters"}}
        result = json.loads(self._post_material_bundle(document).read())
        self.assertEqual(result["id"], "bundle-bubble")
        self.assertEqual(result["fileCount"], 1)
        listing = json.loads(urllib.request.urlopen(self.base + "/api/v1/apps/test-app/versions/1.0.0/interactive-content").read())
        self.assertEqual(next(item for item in listing["items"] if item["id"] == "bundle-bubble")["document"], document)
        self.assertEqual(urllib.request.urlopen(self.base + "/api/v1/assets/bundle-background/download").read(), b"GIF89a bundle bytes")

    def test_material_bundle_must_match_selected_category(self):
        document = {"protocolVersion": "1.0", "id": "wrong-category-bubble", "version": "1", "renderer": "gif", "background": {"assetID": "wrong-category-background", "role": "background-frame"}, "decorations": [], "layout": {"cornerRadius": 12, "paddingTop": 8, "paddingLeading": 8, "paddingBottom": 8, "paddingTrailing": 8}, "parameters": {"assetID": "wrong-category-background", "role": "renderer-parameters"}}
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            self._post_material_bundle(document, category="sticker")
        self.assertEqual(ctx.exception.code, 422)
        self.assertIn("does not match bundle category", ctx.exception.read().decode())

    def test_material_bundle_rejects_missing_protocol_fields_without_partial_publish(self):
        document = {"protocolVersion": "1.0", "id": "incomplete-bundle", "version": "1", "renderer": "gif", "decorations": [], "layout": {"cornerRadius": 12, "paddingTop": 8, "paddingLeading": 8, "paddingBottom": 8, "paddingTrailing": 8}}
        with self.assertRaises(urllib.error.HTTPError) as error:
            self._post_material_bundle(document)
        self.assertEqual(error.exception.code, 422)
        self.assertIn("field declared by protocol is missing", str(json.loads(error.exception.read())))
        listing = json.loads(urllib.request.urlopen(self.base + "/api/v1/apps/test-app/versions/1.0.0/interactive-content").read())
        self.assertNotIn("incomplete-bundle", [item["id"] for item in listing["items"]])

    def test_wrong_app_and_version(self):
        with self.assertRaises(urllib.error.HTTPError) as error:
            urllib.request.urlopen(self.base + "/api/v1/apps/other/versions/1.0.0/assets")
        self.assertEqual(error.exception.code, 404)
        manifest = json.loads(urllib.request.urlopen(self.base + "/api/v1/apps/test-app/versions/2.0.0/assets").read())
        self.assertEqual(manifest["assets"], [])

    def test_unknown_display_slot_is_rejected(self):
        request = urllib.request.Request(self.base + "/api/v1/placements?version=1.0.0",
            data=json.dumps({"slot": "chat.some-random-widget", "assetId": "no-such-asset"}).encode(),
            headers={"Content-Type": "application/json"}, method="POST")
        with self.assertRaises(urllib.error.HTTPError) as error:
            urllib.request.urlopen(request)
        self.assertEqual(error.exception.code, 400)


if __name__ == "__main__":
    unittest.main()
