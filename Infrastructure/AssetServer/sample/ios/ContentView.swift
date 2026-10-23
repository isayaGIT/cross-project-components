import SwiftUI
import UIKit

@MainActor
struct ContentView: View {
    @State private var serverURL = "http://127.0.0.1:8080"
    @State private var appID = "sample-app"
    @State private var version = "1.0.0"
    @State private var slot = "chat.background"
    @State private var interactiveContentID = "bubble.pink.sparkle"
    @State private var interactiveContentStatus = "No protocol document fetched yet."
    @State private var backgroundImage: UIImage?
    @State private var resolvedAssetName = "Not resolved yet"
    @State private var status = "Ready to ask AssetServer which image belongs here."
    @State private var localPath = ""
    @State private var isBusy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SERVER-DRIVEN ASSETS")
                            .font(.caption.weight(.bold))
                            .tracking(1.6)
                            .foregroundStyle(.secondary)
                        Text("The app chooses a slot.\nThe server chooses the image.")
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    GroupBox("Connection") {
                        VStack(spacing: 10) {
                            TextField("AssetServer URL", text: $serverURL)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            Divider()
                            HStack {
                                Text("App ID").foregroundStyle(.secondary)
                                Spacer()
                                TextField("sample-app", text: $appID)
                                    .multilineTextAlignment(.trailing)
                                    .textInputAutocapitalization(.never)
                            }
                            HStack {
                                Text("Version").foregroundStyle(.secondary)
                                Spacer()
                                TextField("1.0.0", text: $version)
                                    .multilineTextAlignment(.trailing)
                            }
                            HStack {
                                Text("Display slot").foregroundStyle(.secondary)
                                Spacer()
                                TextField("chat.background", text: $slot)
                                    .multilineTextAlignment(.trailing)
                                    .textInputAutocapitalization(.never)
                            }
                            Button(action: resolveAndDownload) {
                                HStack {
                                    if isBusy { ProgressView().tint(.white) }
                                    Text(isBusy ? "Syncing asset…" : "Resolve & display background")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isBusy)
                        }
                        .textFieldStyle(.plain)
                    }

                    GroupBox("Interactive content protocol") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Fetch a published StickerPack, animated bubble, or fullscreen animation document. The client checks protocol identity, decodes supported Swift models, and verifies that asset references match the server-generated manifest.")
                                .font(.footnote).foregroundStyle(.secondary)
                            HStack {
                                Text("Content ID").foregroundStyle(.secondary)
                                Spacer()
                                TextField("bubble.pink.sparkle", text: $interactiveContentID)
                                    .multilineTextAlignment(.trailing)
                                    .textInputAutocapitalization(.never)
                            }
                            Button {
                                validateInteractiveContent()
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.shield")
                                    Text("Fetch & validate protocol document")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isBusy)
                            Text(interactiveContentStatus)
                                .font(.footnote)
                                .foregroundStyle(interactiveContentStatus.hasPrefix("Error") ? .red : .secondary)
                                .textSelection(.enabled)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("CHAT PREVIEW").font(.caption.weight(.bold)).tracking(1.4)
                            Spacer()
                            Label("Live slot", systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        chatPreview
                            .frame(height: 330)
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.black.opacity(0.08)))
                    }

                    GroupBox("Resolved by server") {
                        VStack(alignment: .leading, spacing: 7) {
                            infoRow("Slot", slot)
                            infoRow("Asset", resolvedAssetName)
                            if !localPath.isEmpty {
                                infoRow("Persistent asset", URL(fileURLWithPath: localPath).lastPathComponent)
                            }
                            Divider()
                            Text(status)
                                .font(.footnote)
                                .foregroundStyle(status.hasPrefix("Error") ? .red : .secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                    Text("Demo only · local HTTP server · SHA-256 verified before display")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
                .padding(18)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("AssetServer")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if backgroundImage == nil { resolveAndDownload() }
            }
        }
    }

    private var chatPreview: some View {
        ZStack {
            if let backgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                LinearGradient(colors: [Color(red: 1, green: 0.91, blue: 0.94), Color(red: 0.96, green: 0.84, blue: 0.91), Color(red: 1, green: 0.96, blue: 0.91)], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.arrow.down")
                        .font(.system(size: 28))
                    Text("Waiting for server mapping")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.secondary)
            }
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "chevron.left")
                    Spacer()
                    VStack(spacing: 2) {
                        Text("Mia").font(.headline)
                        Text("online").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "ellipsis")
                }
                .padding(12)
                .background(.regularMaterial, in: Capsule())
                Spacer()
                messageBubble("I found a new place for us 🌸", incoming: true)
                messageBubble("Show me!", incoming: false)
                messageBubble("It's beautiful here.", incoming: true)
                Spacer(minLength: 0)
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Message")
                    Spacer()
                    Image(systemName: "mic.fill")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(12)
                .background(.regularMaterial, in: Capsule())
            }
            .padding(12)
        }
    }

    private func messageBubble(_ text: String, incoming: Bool) -> some View {
        HStack {
            if !incoming { Spacer(minLength: 50) }
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(incoming ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(Color(red: 0.95, green: 0.72, blue: 0.81)), in: RoundedRectangle(cornerRadius: 18))
            if incoming { Spacer(minLength: 50) }
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
        .font(.footnote)
    }

    private func makeClient() throws -> AssetServerClient {
        guard let url = URL(string: serverURL),
              let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme), url.host != nil else {
            throw NSError(domain: "AssetServerSample", code: 1, userInfo: [NSLocalizedDescriptionKey: "Enter a valid HTTP or HTTPS URL."])
        }
        return AssetServerClient(baseURL: url)
    }

    private func validateInteractiveContent() {
        isBusy = true
        interactiveContentStatus = "Fetching protocol document and asset manifest…"
        Task {
            defer { isBusy = false }
            do {
                let client = try makeClient()
                let result = try await client.fetchAndValidateInteractiveContent(appID: appID, version: version, contentID: interactiveContentID)
                interactiveContentStatus = "Validated \(result.published.type) · protocol \(result.published.protocolVersion) · content version \(result.published.contentVersion) · \(result.referencedAssetIDs.count) referenced asset(s) matched SHA-256 metadata in the server manifest. This validates structure and references; rendering remains a separate step."
            } catch {
                interactiveContentStatus = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func resolveAndDownload() {
        isBusy = true
        status = "Syncing authoritative display-slot manifest…"
        Task {
            defer { isBusy = false }
            do {
                let client = try makeClient()
                do {
                    let result = try await client.syncAndResolve(appID: appID, version: version, slot: slot)
                    guard let image = UIImage(contentsOfFile: result.url.path) else {
                        throw NSError(domain: "AssetServerSample", code: 2, userInfo: [NSLocalizedDescriptionKey: "The assigned asset is not a supported iOS image. Use PNG or JPEG for this demo."])
                    }
                    backgroundImage = image
                    localPath = result.url.path
                    resolvedAssetName = URL(fileURLWithPath: result.url.path).lastPathComponent
                    status = "Sync complete · \(result.downloaded) downloaded · \(result.reused) verified local asset(s) reused. Stored in Application Support, not Caches. Unassigned assets were pruned."
                } catch {
                    if let localURL = try client.resolveFromPersistentStore(appID: appID, version: version, slot: slot),
                       let image = UIImage(contentsOfFile: localURL.path) {
                        backgroundImage = image
                        localPath = localURL.path
                        resolvedAssetName = localURL.lastPathComponent
                        status = "Server unavailable; showing the last successfully synced persistent asset."
                    } else {
                        throw error
                    }
                }
            } catch AssetServerError.noAssignment(let missingSlot) {
                backgroundImage = nil
                localPath = ""
                resolvedAssetName = "No asset assigned"
                status = "The server confirms that \(missingSlot) has no asset for version \(version). Unassigned local assets were removed during sync."
            } catch {
                status = "Error: \(error.localizedDescription)"
            }
        }
    }
}
