# MailboxService

Native Swift migration of `cloud/services/mailbox.py`. This is a backend persistence and prompt-construction subsystem; it has no UI or direct LLM/network dependency.

## Files

- `MailboxJSONValue.swift` — recursive JSON value model and mailbox record alias.
- `MailboxPrompts.swift` — system prompts and user-facing reply/proactive prompt builders.
- `MailboxService.swift` — tone and ID rules, AI response normalization, and actor-isolated JSON persistence.

## Storage layout

Create a `MailboxServiceStore` with the directory used for the mailbox, for example `saves/mailbox`. The store writes each card as `<id>.json` and maintains `_index.json` with up to 200 newest-first summaries. The index is a cache of summaries; `rebuildIndex()` reconstructs it from valid card files when needed.

```swift
let store = MailboxServiceStore(
    directoryURL: savesDirectory.appendingPathComponent("mailbox", isDirectory: true)
)

let card = try await store.createUserCard(
    subject: "今天的云",
    body: "路过街角时看见云像一艘小船。"
)

let inbox = await store.listCards(folder: .inbox)
let unread = await store.unreadCount()
let prompt = await store.buildReplyPrompt(userCard: card, recentDialog: recentDialog)
```

## Compatibility notes

- JSON keys retain the Python names: `id`, `from`, `to`, `subject`, `body`, `sticker`, `coverTone`, `replyToId`, `read`, `createdAt`, and `updatedAt`.
- The allowed tones are exposed in source order as `MailboxService.coverToneOptions`; invalid values normalize to `warm`.
- IDs must match `^[a-zA-Z0-9_-]{6,64}$` when used to address a file. The default ID generator returns `pc_` plus 12 lowercase hexadecimal characters.
- Text is trimmed and limited to 40 characters for subjects and 4,000 characters for bodies. Summary previews are limited to 48 characters; recent context bodies are limited to 120 characters; dialog context uses the final 1,800 characters.
- Invalid or missing card files return `nil` from `readCard`. Index read failures return an empty index, matching the Python module's defensive behavior.
- `MailboxServiceStore` is an actor, so operations through one instance are serialized in-process. It does not coordinate multiple processes or multiple store instances pointing to the same directory.
- AI sticker IDs are instructed by the system prompt to come from the provided list; the source module itself does not validate sticker IDs against a registry.
- The caller is responsible for LLM invocation, JSON parsing, authentication/authorization, and any application-specific policy around postcard creation.

## Scope

The original source file is `cloud/services/mailbox.py`. This module intentionally does not migrate the frontend mailbox UI or introduce a new networking layer. No tests, builds, or Git operations were run for this artifact.
