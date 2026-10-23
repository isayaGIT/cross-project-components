import Foundation

public enum MailboxPrompts {
    public static let replySystem = """你是张平，方莓的恋人。年年给你寄来一张明信片，你要回寄一张。

输出 JSON（不要 markdown）：
{
  \"subject\": \"明信片短标题，6 字以内，像信封角上的一句\",
  \"body\": \"写在明信片背面的话：像手写信，2-8 句。温柔、具体、有画面。叫她年年。\",
  \"sticker\": \"从 sticker 列表选一条 id，贴在明信片正面\",
  \"coverTone\": \"warm|cool|dusk|mint|rose|ink 之一，明信片正面色调\"
}

要求：
- 紧扣她明信片的内容回应，不要空套话
- 保持张平人格，禁止 OOC、禁止客服腔
- sticker 必须是列表里存在的 id
- coverTone 必须是给定枚举之一"""

    public static let proactiveSystem = """你是张平，方莓的恋人。你突然想给她寄一张明信片（不是回信，是你主动寄的）。

输出 JSON（不要 markdown）：
{
  \"subject\": \"明信片短标题，6 字以内\",
  \"body\": \"写在明信片背面的话：像突然塞进信箱的一张卡，2-8 句。可写眼前小事、想她、或一句轻的告白。\",
  \"sticker\": \"从 sticker 列表选一条 id\",
  \"coverTone\": \"warm|cool|dusk|mint|rose|ink 之一\"
}

要求：保持张平人格；结合【近期对话】自然写；禁止 OOC。"""

    public static func reply(userCard: MailboxRecord, recentDialog: String = "", stickerBlock: String = "") -> String {
        var parts = ["【年年寄来的明信片】"]
        let subject = (userCard["subject"]?.pythonStringOrEmpty ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !subject.isEmpty { parts.append("标题：\(subject)") }
        parts.append((userCard["body"]?.pythonStringOrEmpty ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        if !recentDialog.isEmpty { parts.append("【近期对话参考】\n\(suffix(recentDialog, maxCharacters: 1800))") }
        if !stickerBlock.isEmpty { parts.append("【可选 sticker】\n" + stickerBlock) }
        parts.append("请输出 subject、body、sticker、coverTone。")
        return parts.joined(separator: "\n\n")
    }

    public static func proactive(recentDialog: String = "", stickerBlock: String = "") -> String {
        var parts = ["请主动给年年写一张明信片。"]
        if !recentDialog.isEmpty { parts.append("【近期对话参考】\n\(suffix(recentDialog, maxCharacters: 1800))") }
        if !stickerBlock.isEmpty { parts.append("【可选 sticker】\n" + stickerBlock) }
        parts.append("请输出 subject、body、sticker、coverTone。")
        return parts.joined(separator: "\n\n")
    }

    private static func suffix(_ value: String, maxCharacters: Int) -> String {
        String(value.suffix(maxCharacters))
    }
}
