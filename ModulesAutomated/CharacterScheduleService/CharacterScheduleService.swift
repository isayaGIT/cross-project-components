import Foundation

/// A provider returns JSON text from the requested model. No vendor-specific
/// endpoint, credential, or SDK is assumed by this subsystem.
public typealias ScheduleLLMCall = (_ prompt: String) async throws -> String

/// Search results should use `title` and `snippet` keys. The query, result
/// limit, and optional mode are passed to the caller's search integration.
public typealias ScheduleInspirationSearch = (_ query: String, _ maxResults: Int, _ mode: String?) async throws -> [[String: Any]]

public final class CharacterScheduleService {
    public let store: ScheduleFileStore
    private let llmCall: ScheduleLLMCall?
    private let inspirationSearch: ScheduleInspirationSearch?
    private let systemPrompt: String

    public init(
        store: ScheduleFileStore,
        llmCall: ScheduleLLMCall? = nil,
        inspirationSearch: ScheduleInspirationSearch? = nil,
        systemPrompt: String = ScheduleDefaults.generationSystemPrompt
    ) {
        self.store = store
        self.llmCall = llmCall
        self.inspirationSearch = inspirationSearch
        self.systemPrompt = systemPrompt
    }

    public func generateDaily(options: ScheduleGenerationOptions = ScheduleGenerationOptions()) async throws -> [String: Any]? {
        let date = ScheduleTime.safeDate(options.dateString, now: options.now, calendar: options.calendar)
        if !options.force, let existing = store.readDaily(dateString: date, now: options.now, calendar: options.calendar),
           let blocks = ScheduleJSON.dictionaries(existing["blocks"]), !blocks.isEmpty {
            return existing
        }

        let template = store.loadTemplate()
        guard ScheduleJSON.bool(template["enabled"], default: true) else { return nil }
        let weekday = ScheduleTime.weekday(dateString: date, calendar: options.calendar) ?? 0
        let blocks = ScheduleTime.blocksForDate(template: template, weekday: weekday)
        let persona = Self.personaSnippet(options.personaText)
        let inspiration = await fetchInspiration(template: template, options: options)
        let prompt = Self.buildGeneratePrompt(
            date: date,
            weekday: weekday,
            template: template,
            lifestyleContext: options.lifestyleContext,
            personaSnippet: persona,
            inspiration: inspiration
        )

        var generated: [String: Any]?
        if let llmCall = llmCall {
            do {
                let raw = try await llmCall(systemPrompt + "\n\n" + prompt)
                generated = Self.parseDailyJSON(raw, date: date, now: options.now)
            } catch {
                generated = nil
            }
        }

        if var daily = generated {
            let sleep = ScheduleJSON.dictionary(template["sleep"])
            let parsedBlocks = ScheduleJSON.dictionaries(daily["blocks"]) ?? []
            daily["blocks"] = ScheduleTime.filterSleepBlocks(parsedBlocks, sleep: sleep)
            if !inspiration.isEmpty { daily["inspirationUsed"] = true }
            if (daily["blocks"] as? [[String: Any]] ?? []).isEmpty {
                daily = Self.fallbackDailyFromTemplate(template: template, weekday: weekday, date: date, now: options.now)
            }
            return try store.writeDaily(daily, dateString: date, now: options.now, calendar: options.calendar)
        }

        let fallback = Self.fallbackDailyFromTemplate(template: template, weekday: weekday, date: date, now: options.now)
        return try store.writeDaily(fallback, dateString: date, now: options.now, calendar: options.calendar)
    }

    public func resolveToday(
        options: ScheduleGenerationOptions = ScheduleGenerationOptions(),
        shouldGenerate: Bool = true
    ) async throws -> ResolvedSchedule {
        let date = ScheduleTime.safeDate(options.dateString, now: options.now, calendar: options.calendar)
        let template = store.loadTemplate()
        guard ScheduleJSON.bool(template["enabled"], default: true) else {
            let disabled: [String: Any] = ["enabled": false, "date": date]
            try store.saveState(disabled)
            return ResolvedSchedule(template: template, daily: nil, state: disabled, promptBlock: "")
        }

        var daily = store.readDaily(dateString: date, now: options.now, calendar: options.calendar)
        let hasBlocks = !(ScheduleJSON.dictionaries(daily?["blocks"]) ?? []).isEmpty
        if (!hasBlocks || options.force) && shouldGenerate && llmCall != nil {
            daily = try await generateDaily(options: options)
        } else if !hasBlocks {
            let weekday = ScheduleTime.weekday(dateString: date, calendar: options.calendar) ?? 0
            let fallback = Self.fallbackDailyFromTemplate(template: template, weekday: weekday, date: date, now: options.now)
            daily = try store.writeDaily(fallback, dateString: date, now: options.now, calendar: options.calendar)
        }

        let state = Self.buildRuntimeState(
            daily: daily,
            now: options.now,
            calendar: options.calendar,
            sleepState: options.sleepState
        )
        var enabledState = state
        enabledState["enabled"] = true
        try store.saveState(enabledState)
        let promptBlock = Self.formatPromptBlock(state: enabledState, daily: daily)
        return ResolvedSchedule(template: template, daily: daily, state: enabledState, promptBlock: promptBlock)
    }

    public static func buildRuntimeState(
        daily: [String: Any]?,
        now: Date = Date(),
        calendar: Calendar = .current,
        sleepState: String = ScheduleSleepState.awake
    ) -> [String: Any] {
        let date = ScheduleTime.safeDate(ScheduleJSON.string(daily?["date"]), now: now, calendar: calendar)
        if sleepState == ScheduleSleepState.sleeping || sleepState == ScheduleSleepState.preSleep {
            let sleeping = sleepState == ScheduleSleepState.sleeping
            return [
                "date": date,
                "enabled": true,
                "blockIndex": -1,
                "label": sleeping ? "睡觉" : "准备睡觉",
                "activity": sleeping ? "在睡觉" : "快睡了，可能回复变少",
                "busy": sleeping,
                "until": NSNull(),
                "tag": "sleep"
            ]
        }

        let blocks = ScheduleJSON.dictionaries(daily?["blocks"]) ?? []
        let match = ScheduleTime.currentBlock(blocks: blocks, minute: ScheduleTime.currentMinute(now: now, calendar: calendar))
        guard let block = match.block else {
            let summary = ScheduleJSON.string(daily?["daySummary"]) ?? "在忙别的事或空档"
            return [
                "date": date,
                "enabled": true,
                "blockIndex": -1,
                "label": "空档",
                "activity": summary.isEmpty ? "在忙别的事或空档" : summary,
                "busy": false,
                "until": NSNull(),
                "tag": "gap"
            ]
        }

        let label = ScheduleJSON.string(block["label"]) ?? ""
        var state: [String: Any] = [
            "date": date,
            "enabled": true,
            "blockIndex": match.index,
            "label": label,
            "activity": ScheduleJSON.string(block["activity"]) ?? label,
            "busy": ScheduleJSON.bool(block["busy"]),
            "until": ScheduleJSON.string(block["end"]) ?? NSNull() as Any,
            "tag": ScheduleJSON.string(block["tag"]) ?? "",
            "mood": ScheduleJSON.string(block["mood"]) ?? ""
        ]
        // Keep a concrete dictionary to make the JSON contract explicit.
        state["enabled"] = true
        return state
    }

    public static func personaSnippet(_ text: String, maxLength: Int = 2500) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, maxLength > 0 else { return "" }
        let pattern = #"(?=## L\d+ ##)"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let ns = trimmed as NSString
            let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: ns.length))
            if !matches.isEmpty {
                var segments: [String] = []
                for index in matches.indices {
                    let start = matches[index].range.location
                    let end = index + 1 < matches.count ? matches[index + 1].range.location : ns.length
                    let segment = ns.substring(with: NSRange(location: start, length: end - start)).trimmingCharacters(in: .whitespacesAndNewlines)
                    if segment.hasPrefix("## L0 ##") || segment.hasPrefix("## L1 ##") { segments.append(segment) }
                }
                if !segments.isEmpty { return String(segments.joined(separator: "\n\n").prefix(maxLength)) }
            }
        }
        return String(trimmed.prefix(maxLength))
    }

    public static func parseDailyJSON(_ raw: String, date: String, now: Date = Date()) -> [String: Any]? {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: #"^```(?:json)?\s*"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\s*```$"#, with: "", options: .regularExpression)

        var object: Any?
        if let data = cleaned.data(using: .utf8) {
            object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        }
        if object == nil,
           let regex = try? NSRegularExpression(pattern: #"\{[\s\S]*\}"#),
           let match = regex.firstMatch(in: cleaned, range: NSRange(location: 0, length: (cleaned as NSString).length)) {
            let candidate = (cleaned as NSString).substring(with: match.range)
            if let data = candidate.data(using: .utf8) {
                object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            }
        }
        guard let dictionary = object as? [String: Any],
              let rawBlocks = dictionary["blocks"] as? [Any] else { return nil }

        var blocks: [[String: Any]] = []
        for value in rawBlocks {
            guard let block = value as? [String: Any],
                  let start = ScheduleJSON.string(block["start"]),
                  let end = ScheduleJSON.string(block["end"]),
                  ScheduleTime.minutes(start) != nil,
                  ScheduleTime.minutes(end) != nil else { continue }
            let label = String((ScheduleJSON.string(block["label"]) ?? "").prefix(80))
            let activity = String((ScheduleJSON.string(block["activity"]) ?? label).prefix(200))
            blocks.append([
                "start": String(start.prefix(5)),
                "end": String(end.prefix(5)),
                "label": label,
                "activity": activity,
                "busy": ScheduleJSON.bool(block["busy"]),
                "tag": String((ScheduleJSON.string(block["tag"]) ?? "").prefix(30)),
                "mood": String((ScheduleJSON.string(block["mood"]) ?? "").prefix(40))
            ])
        }
        guard !blocks.isEmpty else { return nil }
        blocks.sort { (ScheduleTime.minutes(ScheduleJSON.string($0["start"])) ?? 0) < (ScheduleTime.minutes(ScheduleJSON.string($1["start"])) ?? 0) }
        return [
            "date": ScheduleTime.safeDate(date, now: now),
            "generatedAt": ScheduleTime.generatedAtMilliseconds(now: now),
            "daySummary": String((ScheduleJSON.string(dictionary["daySummary"]) ?? "").prefix(200)),
            "blocks": blocks
        ]
    }

    public static func fallbackDailyFromTemplate(
        template: [String: Any],
        weekday: Int,
        date: String,
        now: Date = Date()
    ) -> [String: Any] {
        let sleep = ScheduleJSON.dictionary(template["sleep"])
        let sourceBlocks = ScheduleTime.filterSleepBlocks(ScheduleTime.blocksForDate(template: template, weekday: weekday), sleep: sleep)
        let blocks = sourceBlocks.map { block -> [String: Any] in
            let label = ScheduleJSON.string(block["label"]) ?? ""
            return [
                "start": ScheduleJSON.string(block["start"]) ?? "",
                "end": ScheduleJSON.string(block["end"]) ?? "",
                "label": label,
                "activity": ScheduleJSON.string(block["activity"]) ?? label,
                "busy": ScheduleJSON.bool(block["busy"]),
                "tag": ScheduleJSON.string(block["tag"]) ?? "",
                "mood": ScheduleJSON.string(block["mood"]) ?? ""
            ]
        }
        return [
            "date": ScheduleTime.safeDate(date, now: now),
            "generatedAt": ScheduleTime.generatedAtMilliseconds(now: now),
            "daySummary": "按模板过的平常一天",
            "blocks": blocks,
            "source": "template_fallback"
        ]
    }

    public static func buildGeneratePrompt(
        date: String,
        weekday: Int,
        template: [String: Any],
        lifestyleContext: String = "",
        personaSnippet: String = "",
        inspiration: String = ""
    ) -> String {
        let dayNames = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        let dayName = (0..<7).contains(weekday) ? dayNames[weekday] : ""
        var lines = ["日期：\(date)（\(dayName)）"]
        if let sleep = ScheduleJSON.dictionary(template["sleep"]), ScheduleJSON.bool(sleep["enabled"], default: false) {
            lines.append("睡眠：\(ScheduleJSON.string(sleep["bedtime"]) ?? "23:00") 睡觉，\(ScheduleJSON.string(sleep["wakeTime"]) ?? "07:30") 起床；睡眠时段不要安排活动。")
        }
        let blocks = ScheduleTime.blocksForDate(template: template, weekday: weekday)
        lines.append("日程模板：")
        for block in blocks {
            let start = ScheduleJSON.string(block["start"]) ?? ""
            let end = ScheduleJSON.string(block["end"]) ?? ""
            let busy = ScheduleJSON.bool(block["busy"]) ? "忙" : "可聊"
            let label = ScheduleJSON.string(block["label"]) ?? ""
            lines.append("- \(start)–\(end) [\(busy)] \(label)")
        }
        let gapNotes = (template["gapNotes"] as? [Any] ?? []).compactMap { ScheduleJSON.string($0) }.prefix(4)
        if !gapNotes.isEmpty {
            lines.append("空档说明：")
            lines.append(contentsOf: gapNotes.map { "- \($0)" })
        }
        let lifestyle = lifestyleContext.trimmingCharacters(in: .whitespacesAndNewlines)
        if !lifestyle.isEmpty { lines.append("生活背景：\(String(lifestyle.prefix(1500)))") }
        let inspiration = inspiration.trimmingCharacters(in: .whitespacesAndNewlines)
        if !inspiration.isEmpty { lines.append("灵感参考（只参考生活细节，不要照抄）：\n\(String(inspiration.prefix(1200)))") }
        let persona = personaSnippet.trimmingCharacters(in: .whitespacesAndNewlines)
        if !persona.isEmpty { lines.append("角色设定：\n\(String(persona.prefix(2500)))") }
        lines.append("请只输出 JSON，结构为：{\"date\":\"YYYY-MM-DD\",\"daySummary\":\"简短的一天概述\",\"blocks\":[{\"start\":\"HH:MM\",\"end\":\"HH:MM\",\"label\":\"简短标题\",\"activity\":\"具体活动\",\"busy\":false,\"tag\":\"活动分类\",\"mood\":\"情绪\"}]}。")
        lines.append("时间段按时间顺序排列，使用 24 小时制，活动应具体、自然且符合角色生活。不要安排与睡眠冲突的活动；保留合理空档，不要将全天排满。busy 表示角色是否不方便及时回复。")
        return lines.joined(separator: "\n")
    }

    public static func formatPromptBlock(state: [String: Any]?, daily: [String: Any]?) -> String {
        guard let state = state, ScheduleJSON.bool(state["enabled"], default: false),
              let daily = daily,
              let blocks = ScheduleJSON.dictionaries(daily["blocks"]), !blocks.isEmpty else { return "" }
        let label = ScheduleJSON.string(state["activity"]) ?? ScheduleJSON.string(state["label"]) ?? "空档"
        let busy = ScheduleJSON.bool(state["busy"])
        let until = ScheduleJSON.string(state["until"])
        var lines = ["【今日安排】当前：\(label)\(busy ? "（现在不太方便回复）" : "")\(until.map { "，预计到 \($0)" } ?? "")"]
        lines.append("今日时间线：")
        for block in blocks.prefix(8) {
            let start = ScheduleJSON.string(block["start"]) ?? ""
            let end = ScheduleJSON.string(block["end"]) ?? ""
            let activity = ScheduleJSON.string(block["activity"]) ?? ScheduleJSON.string(block["label"]) ?? ""
            let marker = ScheduleJSON.bool(block["busy"]) ? "（忙）" : ""
            lines.append("- \(start)–\(end)：\(activity)\(marker)")
        }
        lines.append("请自然地参考当前活动安排来回应；不要机械复述整份日程，也不要声称已经发生了尚未发生的活动。若角色正在忙或睡觉，回复节奏和内容应符合当前状态。")
        return lines.joined(separator: "\n")
    }

    private func fetchInspiration(template: [String: Any], options: ScheduleGenerationOptions) async -> String {
        guard let search = inspirationSearch, options.maxInspirationQueries > 0 else { return "" }
        let location = ScheduleJSON.string(template["location"]) ?? ""
        var queries: [String] = []
        if !location.isEmpty { queries.append("\(location) 探店 日常") }
        queries.append("兼职 外卖 日常 vlog")
        queries = Array(queries.prefix(options.maxInspirationQueries))
        var output: [String] = []
        for query in queries {
            do {
                let results = try await search(query, 3, options.inspirationMode)
                output.append("搜「\(query)」：")
                for (index, result) in results.prefix(2).enumerated() {
                    let title = String((ScheduleJSON.string(result["title"]) ?? "").prefix(60))
                    let snippet = String((ScheduleJSON.string(result["snippet"]) ?? "").prefix(120))
                    output.append("  \(index + 1). \(title)：\(snippet)")
                }
            } catch {
                // Inspiration is optional. A search failure must not block generation.
                continue
            }
        }
        return output.joined(separator: "\n")
    }
}
