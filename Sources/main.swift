import AppKit
import ApplicationServices
import Carbon
import ServiceManagement
import QuartzCore

let injectedTag: Int64 = 0x4B49594F

enum AppLanguage {
    static func resolve(_ choice: String?, preferred: [String]) -> String {
        if let choice, ["ru", "en"].contains(choice) { return choice }
        for identifier in preferred {
            let base = identifier.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? ""
            if ["ru", "en"].contains(base) { return base }
        }
        return "en"
    }
}

struct LayoutConverter {
    static let en = Array("`qwertyuiop[]asdfghjkl;'zxcvbnm,.")
    static let ru = Array("ёйцукенгшщзхъфывапролджэячсмитьбю")
    static func convert(_ text: String) -> String {
        String(text.map { ch in
            let lower = Character(String(ch).lowercased())
            let from = en.contains(lower) ? en : ru
            let to = en.contains(lower) ? ru : en
            guard let index = from.firstIndex(of: lower) else { return ch }
            let result = String(to[index])
            return Character(ch.isUppercase ? result.uppercased() : result)
        })
    }
    static func russian(_ text: String) -> Bool { text.unicodeScalars.contains { (0x0400...0x04FF).contains(Int($0.value)) } }
    private static var spellingCache: [String: (valid: Bool, checked: TimeInterval)] = [:]
    static func valid(_ text: String, language: String) -> Bool {
        let word = text.lowercased()
        let key = language + "|" + word
        let now = Date.timeIntervalSinceReferenceDate
        if let cached = spellingCache[key], now - cached.checked < 300 { return cached.valid }
        let valid = NSSpellChecker.shared.checkSpelling(of: word, startingAt: 0, language: language, wrap: false, inSpellDocumentWithTag: 0, wordCount: nil).location == NSNotFound
        if spellingCache.count >= 4096 { spellingCache.removeAll(keepingCapacity: true) }
        spellingCache[key] = (valid, now)
        return valid
    }
    static let commonEnglish = Set("hi hello how are you thanks thank please good morning evening night bye yes no the this that what where when why who is am was were have has do does can could would should my your our their it and or but for from with not".split(separator: " ").map(String.init))
    static let technicalEnglish = Set("crm erp api sdk sql html css json xml url uri cpu gpu ram ssd dns vpn tcp udp http https ui ux qa git npm ssh ssl tls csv pdf ios macos saas paas iaas oauth jwt uuid cli gui ide seo smm b2b b2c".split(separator: " ").map(String.init))
    static let developerEnglish = Set("postgres postgresql mysql mariadb sqlite mongodb redis clickhouse elasticsearch opensearch cassandra neo4j supabase firebase python javascript typescript swift kotlin java golang rust ruby php perl scala lua dart elixir clojure haskell bash zsh powershell react nextjs vue nuxt angular svelte node nodejs deno bun express nestjs fastify django flask fastapi rails laravel spring dotnet flutter electron tauri docker kubernetes podman compose container containers image images nginx apache caddy traefik git github gitlab bitbucket commit branch merge rebase checkout stash pull push fetch clone fork diff patch repository repo remote origin main master develop development staging production deploy deployment build release debug debugger debugging test tests testing unittest pytest jest vitest playwright cypress lint eslint prettier format compiler compile runtime framework library package packages dependency dependencies pip poetry uv npm yarn pnpm cargo gradle maven make cmake xcode homebrew brew brewfile vscode cursor neovim vim emacs terminal shell console command script scripts code coding developer developers backend frontend fullstack devops sre ci cd cicd pipeline workflow workflows action actions server client database query queries schema migration migrations table tables index indexes transaction cache caching queue queues worker workers thread threads async await promise callback function functions method methods class classes object objects interface interfaces type types enum struct variable variables constant constants array arrays list lists map dictionary tuple set string boolean integer float null undefined nil optional pointer memory heap stack buffer stream socket port endpoint endpoints request response header headers payload token tokens cookie session auth authentication authorization login logout password username email regex regexp parser parse serialize deserialize serializer deserializer marshal unmarshal protobuf grpc rest graphql websocket webhooks webhook middleware router routes route controller model models view views component components props state hook hooks render rendering hydrate hydration layout template templates styles stylesheet tailwind bootstrap sass scss less webpack vite rollup esbuild babel swc tsc tsconfig jsx tsx wasm oauth jwt uuid guid api apis sdk cli gui ide orm crud solid dry kiss yagni mvc mvvm mvp tdd bdd ddd clean architecture algorithm algorithms recursion recursive iterator iterable generator decorator annotation attribute attributes overload override inheritance polymorphism encapsulation abstraction public private protected static readonly mutable immutable mutex semaphore deadlock race concurrent concurrency parallel parallelism event events listener observer subscriber publisher handler handlers context config configuration settings env dotenv environment localhost loopback host hostname domain dns tcp udp http https ftp sftp ssh ssl tls smtp imap pop html css json xml yaml yml toml ini csv tsv markdown md pdf utf unicode ascii utf8 utf16 binary base64 hex hexadecimal bytes bit bigint decimal precision overflow underflow exception exceptions error errors warning warnings log logs logger logging trace tracing telemetry metrics monitoring observability prometheus grafana sentry datadog kibana ansible terraform pulumi helm kustomize vagrant virtualbox vm linux ubuntu debian alpine fedora centos windows macos ios android ipados x86 arm arm64 amd64 aarch64 web app apps application applications website webapp microservice microservices monolith serverless lambda edge cloud aws azure gcp vercel netlify cloudflare digitalocean hetzner render railway flyio heroku selenium jupyter numpy pandas scipy pytorch tensorflow keras scikit sklearn matplotlib seaborn polars spark kafka rabbitmq nats celery temporal airflow dagster dbt duckdb snowflake bigquery redshift databricks huggingface langchain openai anthropic ollama llama mistral gemini claude codex copilot chatgpt llm rag embedding embeddings vector vectors inference finetuning prompt prompts agent agents tooling benchmark benchmarks snapshot snapshots mock mocks stub stubs fixture fixtures assert assertion assertions expect coverage integration e2e smoke regression performance latency throughput bandwidth uptime downtime retry retries timeout timeouts backoff debounce throttle pagination cursor offset limit batch bulk upsert insert update delete select join group having union distinct where order sort filter reduce find search replace split trim normalize validate validation sanitize escaping encode decode encrypt decrypt hash hashing checksum digest salt pepper secret secrets credential credentials key keys certificate certificates signing signature signatures notarization keychain accessibility sandbox entitlement entitlements plist dmg icns icon icons screenshot screenshots tooltip popover panel window menu menubar notch onboarding locale localization internationalization i18n l10n theme dark light toggle switch dropdown popup dialog sheet modal toast notification notifications badge progress skeleton spinner loading disabled enabled focus blur hover click doubleclick drag drop scroll gesture keyboard keycode shortcut hotkey hotkeys backspace enter return tab space escape capslock shift control option command fn undo redo cut copy paste clipboard selection caret input output stdin stdout stderr exit status pid uid gid chmod chown mkdir rmdir touch cat echo printf sed awk grep rg find ls pwd cd mv cp rm tar zip unzip gzip curl wget ping traceroute dig nslookup ssh rsync scp systemd launchd launchctl process processes daemon service services job jobs cron schedule scheduler timer interval timestamp datetime timezone utc date time duration".split(separator: " ").map(String.init))
    static let languageAndRegionCodes: Set<String> = Set((Locale.LanguageCode.isoLanguageCodes.map(\.identifier) + Locale.Region.isoRegions.map(\.identifier)).filter {
        $0.count == 2 && $0.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ").contains($0) }
    }.map { $0.lowercased() }).union(["en", "ru", "uz", "eu", "ez", "uk"])
    static let developerAliases = ["pyton": "python"]
    static func matchCase(_ value: String, source: String) -> String {
        if source == source.uppercased() { return value.uppercased() }
        if source.first?.isUppercase == true { return value.prefix(1).uppercased() + value.dropFirst() }
        return value
    }
    static let commonRussian = Set("привет пока спасибо пожалуйста как дела что где когда почему кто это да нет не ту то на за по из от до во со ко об он вы мы ты ей её их им ну ли же бы хорошо утро вечер день ночь".split(separator: " ").map(String.init))

    static let englishWords = commonEnglish.union(technicalEnglish).union(developerEnglish).union(["kiyo"])

    static func correction(_ text: String, sensitivity: Int = 1) -> String? {
        if let fixed = wordCorrection(text, sensitivity: sensitivity) { return fixed }
        var word = text
        var suffix = ""
        while let last = word.last, ".,!?;:".contains(last) {
            suffix.insert(word.removeLast(), at: suffix.startIndex)
        }
        guard !suffix.isEmpty, let fixed = wordCorrection(word, sensitivity: sensitivity) else { return nil }
        return fixed + suffix
    }
    static func wordCorrection(_ text: String, sensitivity: Int) -> String? {
        if text.lowercased() == "ру" { return nil }
        if text.lowercased() == "kiyo" { return text == "KiYo" ? nil : "KiYo" }
        guard text.count >= 2 else { return nil }
        let candidate = convert(text)
        let originalWords = russian(text) ? commonRussian : englishWords
        let targetWords = russian(text) ? englishWords : commonRussian
        guard !originalWords.contains(text.lowercased()) else { return nil }
        if russian(text), candidate.lowercased() == "kiyo" { return "KiYo" }
        if targetWords.contains(candidate.lowercased()) { return candidate }
        if russian(text), let alias = developerAliases[candidate.lowercased()] { return matchCase(alias, source: candidate) }
        if russian(text), text.count == 2, text == text.uppercased(), languageAndRegionCodes.contains(candidate.lowercased()) {
            return candidate
        }
        if !russian(text), text.count == 2, text == text.uppercased(), languageAndRegionCodes.contains(text.lowercased()) { return nil }
        guard sensitivity > 0, text.count >= (sensitivity == 2 ? 2 : 3) else { return nil }
        let languages = NSSpellChecker.shared.availableLanguages
        let english = languages.contains("en") ? "en" : languages.first(where: { $0.hasPrefix("en_") }) ?? "en"
        let originalLanguage = russian(text) ? "ru" : english
        let targetLanguage = russian(text) ? english : "ru"
        guard NSSpellChecker.shared.availableLanguages.contains(targetLanguage),
              !valid(text, language: originalLanguage), valid(candidate, language: targetLanguage) else { return nil }
        return candidate
    }
}

enum ExclusionShortcut {
    static let ids = ["ctrlOptK", "ctrlOptE", "ctrlShiftK", "ctrlOptShiftK", "ctrlOptR", "off"]
    static let titles = ["⌃⌥K", "⌃⌥E", "⌃⇧K", "⌃⌥⇧K", "⌃⌥R", "—"]
    static let modifierMask: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
    static func decode(_ id: String) -> (key: Int64, flags: CGEventFlags)? {
        let masks: [CGEventFlags] = [[.maskControl, .maskAlternate], [.maskControl, .maskAlternate], [.maskControl, .maskShift], [.maskControl, .maskAlternate, .maskShift], [.maskControl, .maskAlternate]]
        if let index = ids.firstIndex(of: id), index < masks.count { return (index == 1 ? 14 : index == 4 ? 15 : 40, masks[index]) }
        let parts = id.split(separator: ":")
        guard parts.count == 3, parts[0] == "custom", let key = Int64(parts[1]), let raw = UInt64(parts[2]), (0...127).contains(key), ![54,55,56,57,58,59,60,61,62,63].contains(key) else { return nil }
        let flags = CGEventFlags(rawValue: raw)
        guard flags.intersection(modifierMask) == flags, !flags.intersection([.maskControl, .maskAlternate, .maskCommand]).isEmpty,
              !(key == 49 && flags == [.maskControl, .maskAlternate]) else { return nil }
        return (key, flags)
    }
    static func valid(_ id: String) -> Bool { id == "off" || decode(id) != nil }
    static func encode(key: Int64, flags: CGEventFlags) -> String? {
        let id = "custom:\(key):\(flags.intersection(modifierMask).rawValue)"
        return decode(id) == nil ? nil : id
    }
    static func matches(_ id: String, key: Int64, flags: CGEventFlags) -> Bool {
        guard let shortcut = decode(id) else { return false }
        return key == shortcut.key && flags.intersection(modifierMask) == shortcut.flags
    }
    static func title(_ id: String) -> String {
        guard let shortcut = decode(id) else { return "—" }
        let symbols: [(CGEventFlags, String)] = [(.maskControl, "⌃"), (.maskAlternate, "⌥"), (.maskShift, "⇧"), (.maskCommand, "⌘")]
        let prefix = symbols.filter { shortcut.flags.contains($0.0) }.map { $0.1 }.joined()
        let special: [Int64: String] = [36:"↩",48:"⇥",49:"Space",51:"⌫",53:"⎋",76:"⌤",115:"↖",117:"⌦",119:"↘",116:"⇞",121:"⇟",123:"←",124:"→",125:"↓",126:"↑",122:"F1",120:"F2",99:"F3",118:"F4",96:"F5",97:"F6",98:"F7",100:"F8",101:"F9",109:"F10",103:"F11",111:"F12",105:"F13",107:"F14",113:"F15",106:"F16",64:"F17",79:"F18",80:"F19",90:"F20"]
        if let name = special[shortcut.key] { return prefix + name }
        if let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(), let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) {
            let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue()
            if let bytes = CFDataGetBytePtr(data) {
                let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
                var dead: UInt32 = 0; var count = 0; var chars = [UniChar](repeating: 0, count: 8)
                if UCKeyTranslate(layout, UInt16(shortcut.key), UInt16(kUCKeyActionDown), 0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, chars.count, &count, &chars) == noErr, count > 0 {
                    return prefix + String(utf16CodeUnits: chars, count: count).uppercased()
                }
            }
        }
        return prefix + "Key \(shortcut.key)"
    }
}

struct CorrectionRejections {
    struct Pending {
        var word: String
        var remaining: Int
        var pid: pid_t
        var deadline: Date
        var restoreLayout: Bool
    }
    var pending: Pending?
    private var preserved: (word: String, until: Date)?
    mutating func record(word: String, outputCount: Int, pid: pid_t, now: Date = Date(), restoreLayout: Bool = true) {
        pending = Pending(word: word.lowercased(), remaining: outputCount, pid: pid, deadline: now.addingTimeInterval(15), restoreLayout: restoreLayout)
    }
    mutating func cancel() { pending = nil }
    @discardableResult
    mutating func backspace(pid: pid_t, now: Date = Date()) -> String? {
        guard var attempt = pending, attempt.pid == pid, now <= attempt.deadline else { pending = nil; return nil }
        attempt.remaining -= 1
        if attempt.remaining <= 0 {
            preserved = (attempt.word, now.addingTimeInterval(15))
            pending = nil
            return attempt.restoreLayout ? attempt.word : nil
        } else { pending = attempt }
        return nil
    }
    func shouldPreserve(_ word: String, now: Date = Date()) -> Bool {
        guard let preserved else { return false }
        return preserved.word == word.lowercased() && now <= preserved.until
    }
    mutating func consumePreservation(_ word: String, now: Date = Date()) -> Bool {
        defer { preserved = nil }
        return shouldPreserve(word, now: now)
    }
}

enum SystemSpelling {
    static func distance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs.lowercased()), b = Array(rhs.lowercased())
        var d = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { d[i][0] = i }
        for j in 0...b.count { d[0][j] = j }
        if a.isEmpty || b.isEmpty { return max(a.count, b.count) }
        for i in 1...a.count { for j in 1...b.count {
            d[i][j] = min(d[i-1][j] + 1, d[i][j-1] + 1, d[i-1][j-1] + (a[i-1] == b[j-1] ? 0 : 1))
            if i > 1 && j > 1 && a[i-1] == b[j-2] && a[i-2] == b[j-1] { d[i][j] = min(d[i][j], d[i-2][j-2] + 1) }
        } }
        return d[a.count][b.count]
    }
    static func bestSuggestion(_ word: String, candidates: [String]) -> String? {
        let ranked = Set(candidates.map { $0.lowercased() }).filter { $0 != word.lowercased() && safeSuggestion($0, for: word) }.map { ($0, distance(word, $0)) }.sorted { $0.1 < $1.1 }
        guard let first = ranked.first, first.1 <= 2 || first.0.replacingOccurrences(of: " ", with: "") == word.lowercased(), ranked.count == 1 || first.1 < ranked[1].1 else { return nil }
        return first.0
    }
    static func joinedWordSuggestions(_ word: String, language: String) -> [String] {
        guard language == "ru", (4...48).contains(word.count) else { return [] }
        let letters = Array(word.lowercased())
        let started = Date()
        var checks = 0
        var exhausted = false
        var validity: [String: Bool] = [:]
        let singleLetterWords: Set<String> = ["а", "в", "и", "к", "о", "с", "у", "я"]
        func isWord(_ part: String) -> Bool {
            if part.count == 1 { return singleLetterWords.contains(part) }
            if let known = validity[part] { return known }
            guard checks < 128, Date().timeIntervalSince(started) < 0.06 else { exhausted = true; return false }
            checks += 1
            let valid = LayoutConverter.valid(part, language: language)
            validity[part] = valid
            return valid
        }
        var memo: [String: [[String]]] = [:]
        func paths(_ start: Int, _ remaining: Int) -> [[String]] {
            let key = "\(start):\(remaining)"
            if let known = memo[key] { return known }
            if remaining == 1 {
                let tail = String(letters[start...])
                let result = isWord(tail) ? [[tail]] : []
                memo[key] = result
                return result
            }
            guard letters.count - start >= remaining else { return [] }
            var result: [[String]] = []
            for end in (start + 1)...(letters.count - remaining + 1) {
                let part = String(letters[start..<end])
                guard isWord(part) else { if exhausted { return [] }; continue }
                for suffix in paths(end, remaining - 1) {
                    result.append([part] + suffix)
                    if result.count > 1 { memo[key] = result; return result }
                }
                if exhausted { return [] }
            }
            memo[key] = result
            return result
        }
        // Prefer fewer words. For that word count, require exactly one complete segmentation.
        for count in 2...4 {
            let candidates = paths(0, count)
            guard !exhausted else { return [] }
            if candidates.count > 1 { return [] }
            if let candidate = candidates.first { return [candidate.joined(separator: " ")] }
        }
        return []
    }
    static func safeSuggestion(_ text: String, for word: String) -> Bool {
        let parts = text.split(separator: " ", omittingEmptySubsequences: false)
        return (1...4).contains(parts.count) && parts.allSatisfy { part in
            !part.isEmpty && part.unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) } && LayoutConverter.russian(String(part)) == LayoutConverter.russian(word)
        }
    }
    static func correction(_ text: String) -> String? {
        var word = text
        var suffix = ""
        while let last = word.last, ".,!?;:".contains(last) { suffix.insert(word.removeLast(), at: suffix.startIndex) }
        guard word.count >= 4, word.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) }),
              word != word.uppercased(), !word.dropFirst().contains(where: { $0.isUppercase }),
              !LayoutConverter.englishWords.contains(word.lowercased()),
              !LayoutConverter.commonRussian.contains(word.lowercased()) else { return nil }
        let languages = NSSpellChecker.shared.availableLanguages
        let language = LayoutConverter.russian(word) ? "ru" : languages.contains("en") ? "en" : "en_US"
        guard languages.contains(language), !LayoutConverter.valid(word, language: language) else { return nil }
        let range = NSRange(location: 0, length: (word as NSString).length)
        var candidates = NSSpellChecker.shared.guesses(forWordRange: range, in: word, language: language, inSpellDocumentWithTag: 0) ?? []
        let proposal = NSSpellChecker.shared.correction(forWordRange: range, in: word, language: language, inSpellDocumentWithTag: 0)
        if let proposal { candidates.append(proposal) }
        candidates += joinedWordSuggestions(word, language: language)
        let safeProposal = proposal.flatMap { bestSuggestion(word, candidates: [$0]) }
        guard let suggestion = bestSuggestion(word, candidates: candidates) ?? safeProposal else { return nil }
        return LayoutConverter.matchCase(suggestion.lowercased(), source: word) + suffix
    }
}

struct ExclusionRules {
    static func wordsFromSelection(_ text: String) -> Set<String> {
        guard text.count <= 512 else { return [] }
        return Set(text.components(separatedBy: .whitespacesAndNewlines).map {
            normalize($0).trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:\"()[]{}"))
        }.filter { !$0.isEmpty && $0.count <= 64 })
    }
    static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    static func protectedToken(_ text: String, words: Set<String>) -> Bool {
        let token = normalize(text).trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:"))
        return text.contains("@") || text.contains("://") || token.hasPrefix("www.") ||
            text.unicodeScalars.contains(where: { CharacterSet.decimalDigits.contains($0) }) ||
            words.contains(token) || words.contains(normalize(LayoutConverter.convert(token)))
    }
}

final class NotchView: NSView {
    var roundTop = false
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 18, yRadius: 18).fill()
        if !roundTop { NSRect(x: 0, y: 0, width: bounds.width, height: min(20, bounds.height)).fill() }
    }
}
final class ContentView: NSView {
    override var isFlipped: Bool { true }
}
final class KiyoPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class App: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var tap: CFMachPort?
    var buffer = ""
    var ignoringLongToken = false
    var correctionRejections = CorrectionRejections()
    var enabled = UserDefaults.standard.object(forKey: "correctionEnabled") as? Bool ?? true
    var replacing = false
    // Tests capture output without posting keyboard events or changing the system layout.
    var testOutput: ((CGEvent) -> Void)?
    var testRussian = false
    var testProtectedField = false
    var testExcludedWords: Set<String>?
    var testShortcutID: String?
    var testSelection: String?
    var shortcutRecordingKey = "exclusionShortcut"
    var selectionEpoch = 0
    var testConversionShortcutID: String?
    var testConvertedSelection: String?
    var shortcutBusy = false
    var shortcutHUD: NSPanel?
    var shortcutRecorder: NSPanel?
    var shortcutMonitor: Any?
    var testSensitivity: Int?
    var testShortWords: Bool?
    var testSpellingEnabled: Bool?
    var callbackMaximumMS: Double = 0
    var tapTimeouts = 0
    var activeEventProxy: CGEventTapProxy?
    var observedKeys = 0
    var observedLetters = 0
    var corrections = 0
    var layoutChanges = 0
    var panel: NSPanel!
    var statusItem: NSStatusItem?
    var usesMenuBar = false
    var presentationPreference: String { UserDefaults.standard.string(forKey: "presentation") ?? "menubar" }
    var expanded = false
    var status: NSTextField!
    var content: ContentView?
    var settingsWindow: NSWindow?
    var welcomeWindow: NSWindow?
    var aboutWindow: NSWindow?
    var guideWindow: NSWindow?
    var documentWindows: [String: NSWindow] = [:]
    lazy var preferencesSync = PreferencesSync()
    var syncStatusLabel: NSTextField?
    var syncButton: NSButton?
    var animating = false
    var animationTimer: Timer?
    var outsideSince: Date?
    var headerHeight: CGFloat = 32
    var panelWidth: CGFloat = 360
    var bodyHeight: CGFloat { 220 }
    var notchWidth: CGFloat = 180
    var pendingLayoutChange: (russian: Bool, until: Date)?
    var layoutBufferResets = 0
    var skippedReasons: [String: Int] = [:]
    func recordSkip(_ reason: String) { skippedReasons[reason, default: 0] += 1 }
    var currentRussian = false
    var lastOriginal = ""
    var lastCorrected = ""
    var language: String { AppLanguage.resolve(UserDefaults.standard.string(forKey: "language"), preferred: Locale.preferredLanguages) }
    var exceptionEditor: NSTextView?
    var exceptionPanel: NSPanel?
    var excludedWords: Set<String> {
        testExcludedWords ?? Set((UserDefaults.standard.stringArray(forKey: "excludedWords") ?? []).map(ExclusionRules.normalize))
    }
    var spellingEnabled: Bool { testSpellingEnabled ?? UserDefaults.standard.bool(forKey: "spellingEnabled") }
    var loginEnabled: Bool { SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval }
    var shortWords: Bool { testShortWords ?? UserDefaults.standard.object(forKey: "shortWords") as? Bool ?? true }
    var sensitivity: Int { testSensitivity ?? UserDefaults.standard.object(forKey: "sensitivity") as? Int ?? 1 }
    func tr(_ ru: String, _ en: String) -> String { language == "en" ? en : ru }
    var notice = "Готов к работе"
    var lastPID: pid_t = 0

    var instanceLock: SingleInstanceLock?
    var secondaryInstance = false
    var startupError: Error?
    private static let reopenNotification = Notification.Name("io.ravensystems.kiyo.reopen")

    func applicationWillFinishLaunching(_ notification: Notification) {
        if !secondaryInstance && startupError == nil {
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(reopenFromAnotherCopy), name: Self.reopenNotification, object: nil)
        }
    }
    @objc func reopenFromAnotherCopy(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in self?.revealInterface() }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if secondaryInstance {
            // Finish the Launch Services handshake before closing the extra copy.
            DispatchQueue.main.async {
                DistributedNotificationCenter.default().postNotificationName(Self.reopenNotification, object: nil, userInfo: nil, deliverImmediately: true)
                NSApp.terminate(nil)
            }
            return
        }
        if startupError != nil {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let alert = NSAlert()
                alert.messageText = self.tr("Не удалось запустить KiYo", "KiYo could not start")
                alert.informativeText = self.tr("Не удалось открыть служебный файл в папке Application Support. Проверьте доступ к папке и повторите запуск.", "Could not open the instance file in Application Support. Check folder access and try again.")
                alert.runModal()
                NSApp.terminate(nil)
            }
            return
        }
        // Static NSServices are registered by macOS from Info.plist.
        NSApp.servicesProvider = self
        currentRussian = activeLayoutIsRussian()
        createPanel()
        configureAppMenu()
        if CommandLine.arguments.contains("--settings") { showSettings() }
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        startListening(prompt: false)
        preferencesSync.onApply = { [weak self] in self?.applySyncedPreferences() }
        preferencesSync.onStatus = { [weak self] in self?.updateSyncStatus() }
        preferencesSync.start()
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkMouse()
        }
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.tap == nil && AXIsProcessTrusted() { self.startListening(prompt: false) }
            self.writeHealth()
        }
        if CommandLine.arguments.contains("--welcome") || !UserDefaults.standard.bool(forKey: "welcomeCompleted") {
            DispatchQueue.main.async { [weak self] in self?.showWelcome() }
        }
    }
    @objc func screenChanged() {
        animationTimer?.invalidate()
        animating = false
        expanded = false
        configurePresentation()
        positionPanel()
        render()
    }
    func createPanel() {
        panel = KiyoPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 32), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NotchView(frame: panel.contentView!.bounds)
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.masksToBounds = true
        configurePresentation()
        positionPanel()
        render()
        if !usesMenuBar { panel.orderFrontRegardless() }
    }
    func configurePresentation() {
        usesMenuBar = presentationPreference == "menubar" || CommandLine.arguments.contains("--menu-bar") || !NSScreen.screens.contains(where: { $0.safeAreaInsets.top > 0 })
        (panel.contentView as? NotchView)?.roundTop = usesMenuBar
        if usesMenuBar {
            if statusItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                if let button = item.button {
                    let icon = notchLogo()
                    icon.size = NSSize(width: 18, height: 20)
                    button.image = icon
                    button.target = self
                    button.action = #selector(statusItemClicked(_:))
                    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
                    button.toolTip = "KiYo"
                    button.setAccessibilityLabel("KiYo")
                }
                statusItem = item
            }
            if !expanded { panel.orderOut(nil) }
        } else {
            if let item = statusItem { NSStatusBar.system.removeStatusItem(item); statusItem = nil }
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        }
    }
    @objc func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            for (title, action) in [
                (tr("Настройки…", "Settings…"), #selector(showSettings)),
                (enabled ? tr("Пауза", "Pause") : tr("Продолжить", "Resume"), #selector(toggleEnabled)),
                (tr("О KiYo", "About KiYo"), #selector(showAbout)),
                (tr("Инструкция", "User guide"), #selector(showGuide)),
                (tr("Разрешения…", "Permissions…"), #selector(permissions)),
                (tr("Завершить KiYo", "Quit KiYo"), #selector(quit))
            ] {
                let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
                item.target = self
                menu.addItem(item)
            }
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.minY), in: sender)
        } else { expand() }
    }
    func targetFrame() -> NSRect {
        if usesMenuBar {
            headerHeight = 0
            panelWidth = 240
            let window = statusItem?.button?.window
            let screen = window?.screen ?? NSScreen.main ?? NSScreen.screens[0]
            let anchor = window?.frame ?? NSRect(x: screen.visibleFrame.maxX - 30, y: screen.visibleFrame.maxY, width: 24, height: 24)
            let x = max(screen.visibleFrame.minX + 8, min(anchor.midX - panelWidth / 2, screen.visibleFrame.maxX - panelWidth - 8))
            let height = expanded ? bodyHeight : 1
            return NSRect(x: x, y: anchor.minY - 6 - height, width: panelWidth, height: height)
        }
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens[0]
        headerHeight = max(30, screen.safeAreaInsets.top)
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            notchWidth = right.minX - left.maxX
        } else { notchWidth = 180 }
        panelWidth = max(240, notchWidth + 32)
        let height = headerHeight + (expanded ? bodyHeight : 0)
        return NSRect(x: screen.frame.midX - panelWidth / 2, y: screen.frame.maxY - height, width: panelWidth, height: height)
    }
    func positionPanel() {
        panel.setFrame(targetFrame(), display: true)
        panel.contentView?.needsDisplay = true
    }
    @discardableResult
    func label(_ text: String, x: CGFloat = 24, y: CGFloat, width: CGFloat? = nil, size: CGFloat = 13, center: Bool = false, muted: Bool = false) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.frame = NSRect(x: x, y: y, width: width ?? panelWidth - 48, height: size + 12)
        field.font = .systemFont(ofSize: panelWidth < 280 && size <= 14 ? min(size, 11) : size, weight: size >= 24 ? .semibold : .regular)
        field.textColor = muted ? NSColor(white: 0.64, alpha: 1) : .white
        field.alignment = center ? .center : .left
        field.lineBreakMode = .byTruncatingTail
        content?.addSubview(field)
        return field
    }
    func button(_ title: String, x: CGFloat = 24, y: CGFloat, width: CGFloat? = nil, action: Selector) {
        let b = NSButton(title: title, target: self, action: action)
        b.frame = NSRect(x: x, y: y, width: width ?? panelWidth - 48, height: 30)
        b.isBordered = false
        b.contentTintColor = .white
        b.font = .systemFont(ofSize: 12)
        content?.addSubview(b)
    }
    func separator(_ y: CGFloat, fullWidth: Bool = false) {
        let line = NSView(frame: NSRect(x: fullWidth ? 0 : 24, y: y, width: fullWidth ? panelWidth : panelWidth - 48, height: 1))
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor(white: 0.14, alpha: 1).cgColor
        content?.addSubview(line)
    }
    func switchRow(_ title: String, y: CGFloat, on: Bool, action: Selector) {
        label(title, y: y + 4, width: panelWidth - 112)
        let control = NSSwitch(frame: NSRect(x: panelWidth - 66, y: y, width: 42, height: 30))
        control.state = on ? .on : .off
        control.target = self
        control.action = action
        content?.addSubview(control)
    }
    func notchLogo() -> NSImage {
        if let source = Bundle.main.image(forResource: "LogoTemplate") {
            let image = NSImage(size: NSSize(width: 22, height: 25), flipped: false) { rect in
                source.draw(in: rect, from: NSRect(x: 174, y: 86, width: 922, height: 1032), operation: .sourceOver, fraction: 1)
                return true
            }
            image.isTemplate = true
            return image
        }
        let image = NSImage(size: NSSize(width: 22, height: 24), flipped: false) { rect in
            let base = NSFont.systemFont(ofSize: 12, weight: .heavy)
            let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 12) } ?? base
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
            for (text, baseline) in [("Ki", CGFloat(11)), ("Yo", CGFloat(0))] {
                let string = NSAttributedString(string: text, attributes: attributes)
                string.draw(at: NSPoint(x: (rect.width - string.size().width) / 2, y: baseline))
            }
            return true
        }
        image.isTemplate = true
        return image
    }
    func render() {
        guard !animating else { return }
        panel.contentView?.subviews.forEach { $0.removeFromSuperview() }
        let head = NSButton(title: "", target: self, action: #selector(expand))
        let headerLogo = notchLogo()
        headerLogo.size = NSSize(width: 14, height: 16)
        head.image = expanded ? nil : headerLogo
        head.imagePosition = .imageOnly
        head.imageScaling = .scaleProportionallyDown
        head.isBordered = false
        head.contentTintColor = .white
        head.font = .systemFont(ofSize: 17, weight: .semibold)
        head.frame = NSRect(x: 4, y: 0, width: (panelWidth - notchWidth) / 2 - 4, height: headerHeight)
        head.setAccessibilityLabel(tr("Раскрыть или свернуть KiYo", "Expand or collapse KiYo"))
        if !usesMenuBar { panel.contentView?.addSubview(head) }
        guard expanded else { content = nil; return }
        content = ContentView(frame: NSRect(x: 0, y: headerHeight, width: panelWidth, height: bodyHeight))
        panel.contentView?.addSubview(content!)
        let logo = NSImageView(frame: NSRect(x: panelWidth / 2 - 22, y: 0, width: 44, height: 48))
        logo.image = notchLogo()
        logo.imageScaling = .scaleProportionallyUpOrDown
        logo.contentTintColor = .white
        logo.setAccessibilityLabel("KiYo")
        content?.addSubview(logo)
        let state = tap == nil ? tr("Нет доступа к клавиатуре", "Keyboard access required") : enabled ? tr("●  Автосмена включена", "●  Auto correction enabled") : tr("Автосмена на паузе", "Auto correction paused")
        status = label(state, y: 48, size: 12, center: true, muted: true)
        if tap != nil && enabled { status.textColor = NSColor.systemGreen }
        label(currentRussian ? "РУ → EN" : "EN → РУ", y: 80, size: 19, center: true)
        label(lastOriginal.isEmpty ? tr("Исправление после пробела", "Correction after a space") : lastOriginal, y: 114, center: true, muted: true)
        if tap == nil {
            button(tr("Разрешить доступ", "Allow access"), x: 12, y: 137, width: panelWidth - 24, action: #selector(permissions))
        } else {
            label(lastCorrected.isEmpty ? tr("Печатайте как обычно", "Type as usual") : lastCorrected, y: 140, size: lastCorrected.isEmpty ? 12 : 18, center: true, muted: lastCorrected.isEmpty)
        }
        separator(178, fullWidth: true)
        iconButton("gearshape", title: tr("Настройки", "Settings"), x: panelWidth / 2 - 66, action: #selector(showSettings))
        iconButton(enabled ? "pause" : "play", title: enabled ? tr("Пауза", "Pause") : tr("Продолжить", "Resume"), x: panelWidth / 2 + 22, action: #selector(toggleEnabled))
    }
    func iconButton(_ symbol: String, title: String, x: CGFloat, action: Selector) {
        let control = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: title)!, target: self, action: action)
        control.frame = NSRect(x: x, y: 182, width: 44, height: 36)
        control.isBordered = false
        control.imagePosition = .imageOnly
        control.image = control.image?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 17, weight: .medium))
        control.contentTintColor = .white
        control.toolTip = title
        control.setAccessibilityLabel(title)
        content?.addSubview(control)
    }
    func refreshSettings() {
        guard let window = settingsWindow else { return }
        window.title = ""
        window.titleVisibility = .hidden
        let root = ContentView(frame: NSRect(x: 0, y: 0, width: 480, height: 626))
        window.contentView = root
        func group(_ title: String, y: CGFloat, height: CGFloat) -> ContentView {
            let box = NSBox(frame: NSRect(x: 20, y: y, width: 440, height: height))
            box.title = ""
            box.titlePosition = .noTitle
            box.boxType = .primary
            let body = ContentView(frame: .zero)
            box.contentViewMargins = .zero
            box.contentView = body
            root.addSubview(box)
            return body
        }
        func row(_ parent: NSView, _ title: String, y: CGFloat, control: NSControl) {
            let name = NSTextField(labelWithString: title)
            name.font = .systemFont(ofSize: 13)
            name.textColor = .labelColor
            name.translatesAutoresizingMaskIntoConstraints = false
            control.translatesAutoresizingMaskIntoConstraints = false
            parent.addSubview(name)
            parent.addSubview(control)
            let isSwitch = control is NSSwitch
            let isLanguage = control is NSPopUpButton
            NSLayoutConstraint.activate([
                name.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: 16),
                name.centerYAnchor.constraint(equalTo: control.centerYAnchor),
                name.trailingAnchor.constraint(lessThanOrEqualTo: control.leadingAnchor, constant: -16),
                control.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: isSwitch ? -24 : -16),
                control.topAnchor.constraint(equalTo: parent.topAnchor, constant: y),
                control.widthAnchor.constraint(equalToConstant: isSwitch ? 38 : 180),
                control.heightAnchor.constraint(equalToConstant: isLanguage ? 34 : 28)
            ])
        }
        func toggle(_ state: Bool, _ action: Selector) -> NSSwitch {
            let control = NSSwitch()
            control.state = state ? .on : .off
            control.target = self; control.action = action
            return control
        }
        let general = group("", y: 12, height: 558)
        let languages = NSPopUpButton()
        languages.controlSize = .large
        languages.addItems(withTitles: [tr("Системный", "System default"), "Русский", "English"])
        languages.selectItem(at: ["system", "ru", "en"].firstIndex(of: UserDefaults.standard.string(forKey: "language") ?? "system") ?? 0)
        languages.target = self; languages.action = #selector(changeLanguage(_:))
        row(general, tr("Язык приложения", "App language"), y: 16, control: languages)
        row(general, tr("Запуск при входе", "Launch at login"), y: 54, control: toggle(loginEnabled, #selector(toggleLogin)))
        let correction = general
        row(correction, tr("Автоисправление", "Auto correction"), y: 90, control: toggle(enabled, #selector(toggleEnabled)))
        row(correction, tr("Исправление орфографии", "Spelling correction"), y: 126, control: toggle(spellingEnabled, #selector(toggleSpelling)))
        row(correction, tr("Короткие слова", "Short words"), y: 162, control: toggle(shortWords, #selector(toggleShort)))
        let sensitivityControl = NSSegmentedControl(labels: language == "en" ? ["Low", "Medium", "High"] : ["Низкая", "Средняя", "Высокая"], trackingMode: .selectOne, target: self, action: #selector(changeSensitivity(_:)))
        sensitivityControl.selectedSegment = sensitivity
        sensitivityControl.font = .systemFont(ofSize: 11)
        row(correction, tr("Чувствительность", "Sensitivity"), y: 198, control: sensitivityControl)
        let exceptions = NSButton(title: tr("Изменить…", "Edit…"), target: self, action: #selector(editExceptions))
        exceptions.bezelStyle = .rounded
        row(general, tr("Слова-исключения", "Excluded words"), y: 234, control: exceptions)
        let shortcut = NSButton(title: ExclusionShortcut.title(UserDefaults.standard.string(forKey: "exclusionShortcut") ?? "ctrlOptK"), target: self, action: #selector(recordExclusionShortcut))
        shortcut.bezelStyle = .rounded
        shortcut.toolTip = tr("Нажмите, чтобы назначить своё сочетание", "Click to record your own shortcut")
        row(general, tr("Добавить выделение", "Add selection"), y: 270, control: shortcut)
        let shortcutHelp = NSTextField(wrappingLabelWithString: tr("Нажмите кнопку справа и задайте сочетание. Выделите текст и нажмите его, чтобы добавить слова в исключения.", "Click the button on the right to set a shortcut. Select text and press the shortcut to add the words to exceptions."))
        shortcutHelp.font = .systemFont(ofSize: 11)
        shortcutHelp.textColor = .secondaryLabelColor
        shortcutHelp.frame = NSRect(x: 16, y: 302, width: 408, height: 34)
        general.addSubview(shortcutHelp)
        let convertShortcut = NSButton(title: ExclusionShortcut.title(UserDefaults.standard.string(forKey: "convertSelectionShortcut") ?? "ctrlOptR"), target: self, action: #selector(recordConversionShortcut))
        convertShortcut.bezelStyle = .rounded
        convertShortcut.toolTip = tr("Исправить раскладку выделенного текста. Нажмите, чтобы назначить сочетание.", "Convert the keyboard layout of selected text. Click to record a shortcut.")
        row(general, tr("Исправить выделение", "Convert selection"), y: 342, control: convertShortcut)
        let presentation = NSPopUpButton()
        presentation.controlSize = .large
        presentation.addItems(withTitles: language == "en" ? ["Automatic", "In the notch", "In the status bar"] : ["Автоматически", "В чёлке", "В статус-баре"])
        presentation.selectItem(at: ["automatic", "notch", "menubar"].firstIndex(of: presentationPreference) ?? 0)
        presentation.target = self
        presentation.action = #selector(changePresentation(_:))
        row(general, tr("Отображение", "Display mode"), y: 378, control: presentation)
        let about = NSButton(title: tr("О KiYo", "About KiYo"), target: self, action: #selector(showAbout))
        about.bezelStyle = .rounded
        row(general, tr("О приложении", "Application"), y: 414, control: about)
        let guide = NSButton(title: tr("Открыть", "Open"), target: self, action: #selector(showGuide))
        guide.bezelStyle = .rounded
        row(general, tr("Инструкция", "User guide"), y: 450, control: guide)
        let sync = NSButton(title: preferencesSync.connected ? tr("Отключить", "Disconnect") : tr("Подключить…", "Connect…"), target: self, action: #selector(configureSync))
        sync.bezelStyle = .rounded
        syncButton = sync
        row(general, tr("iCloud Drive", "iCloud Drive"), y: 486, control: sync)
        let syncInfo = NSTextField(labelWithString: "")
        syncInfo.font = .systemFont(ofSize: 11)
        syncInfo.textColor = .secondaryLabelColor
        syncInfo.frame = NSRect(x: 16, y: 526, width: 408, height: 18)
        general.addSubview(syncInfo)
        syncStatusLabel = syncInfo
        updateSyncStatus()
        let access = NSTextField(labelWithString: tap == nil ? tr("Нет доступа к клавиатуре", "Keyboard access required") : tr("Доступ к клавиатуре включён", "Keyboard access enabled"))
        access.textColor = .secondaryLabelColor
        access.font = .systemFont(ofSize: 11)
        access.alignment = .center
        access.frame = NSRect(x: 110, y: 592, width: 260, height: 20)
        root.addSubview(access)
        let permissions = NSButton(title: tr("Разрешения…", "Permissions…"), target: self, action: #selector(permissions))
        permissions.bezelStyle = .rounded
        permissions.controlSize = .small
        permissions.frame = NSRect(x: 366, y: 586, width: 94, height: 28)
        root.addSubview(permissions)
        let quit = NSButton(title: tr("Завершить", "Quit"), target: self, action: #selector(quit))
        quit.bezelStyle = .rounded
        quit.controlSize = .small
        quit.frame = NSRect(x: 20, y: 586, width: 90, height: 28)
        root.addSubview(quit)
    }
    @objc func editExceptions() {
        guard let parent = settingsWindow else { return }
        let sheet = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 290), styleMask: [.titled], backing: .buffered, defer: false)
        sheet.title = tr("Слова-исключения", "Excluded words")
        let root = ContentView(frame: sheet.contentView!.bounds)
        sheet.contentView = root
        let hint = NSTextField(wrappingLabelWithString: tr("Одно слово в строке, без учёта регистра. Не вводите сюда пароли: защищённые поля пропускаются автоматически.", "One word per line, case insensitive. Do not enter passwords: secure fields are skipped automatically."))
        hint.frame = NSRect(x: 20, y: 14, width: 380, height: 46)
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .secondaryLabelColor
        root.addSubview(hint)
        let scroll = NSScrollView(frame: NSRect(x: 20, y: 68, width: 380, height: 162))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 360, height: 162))
        editor.isRichText = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.font = .systemFont(ofSize: 13)
        editor.string = excludedWords.sorted().joined(separator: "\n")
        scroll.documentView = editor
        root.addSubview(scroll)
        let cancel = NSButton(title: tr("Отмена", "Cancel"), target: self, action: #selector(cancelExceptions))
        cancel.bezelStyle = .rounded
        cancel.frame = NSRect(x: 196, y: 247, width: 94, height: 28)
        root.addSubview(cancel)
        let save = NSButton(title: tr("Сохранить", "Save"), target: self, action: #selector(saveExceptions))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        save.frame = NSRect(x: 296, y: 247, width: 104, height: 28)
        root.addSubview(save)
        exceptionEditor = editor; exceptionPanel = sheet
        parent.beginSheet(sheet)
    }
    @objc func cancelExceptions() {
        if let sheet = exceptionPanel { settingsWindow?.endSheet(sheet) }
        exceptionEditor = nil; exceptionPanel = nil
    }
    @objc func saveExceptions() {
        let words = Set((exceptionEditor?.string ?? "").components(separatedBy: .newlines).map(ExclusionRules.normalize).filter { !$0.isEmpty })
        UserDefaults.standard.set(words.sorted(), forKey: "excludedWords")
        buffer = ""
        cancelExceptions()
    }
    func protectedField(pid: pid_t) -> Bool {
        if testOutput != nil { return testProtectedField }
        if pid == ProcessInfo.processInfo.processIdentifier { return true }
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.01)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return true }
        let element = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.01)
        for attribute in [kAXSubroleAttribute, kAXRoleDescriptionAttribute, kAXPlaceholderValueAttribute] {
            var value: CFTypeRef?
            AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
            let text = (value as? String ?? "").lowercased()
            if text.contains("secure") || text.contains("password") || text.contains("парол") || text.contains("email") || text.contains("e-mail") || text.contains("электронн") { return true }
        }
        return false
    }
    func finishShortcutRecording(_ value: String?) {
        if let value, let chosen = ExclusionShortcut.decode(value) {
            let otherKey = shortcutRecordingKey == "exclusionShortcut" ? "convertSelectionShortcut" : "exclusionShortcut"
            let other = UserDefaults.standard.string(forKey: otherKey) ?? (otherKey == "exclusionShortcut" ? "ctrlOptK" : "ctrlOptR")
            if ExclusionShortcut.matches(other, key: chosen.key, flags: chosen.flags) {
                (shortcutRecorder?.contentView?.subviews.first as? NSTextField)?.stringValue = tr("Это сочетание уже используется KiYo", "This shortcut is already used by KiYo")
                return
            }
        }
        if let monitor = shortcutMonitor { NSEvent.removeMonitor(monitor); shortcutMonitor = nil }
        if let sheet = shortcutRecorder { settingsWindow?.endSheet(sheet); sheet.orderOut(nil) }
        shortcutRecorder = nil
        if let value { UserDefaults.standard.set(value, forKey: shortcutRecordingKey) }
        buffer = ""
        refreshSettings()
    }
    @objc func cancelShortcutRecording() { finishShortcutRecording(nil) }
    @objc func disableShortcutRecording() { finishShortcutRecording("off") }
    @objc func resetShortcutRecording() { finishShortcutRecording(shortcutRecordingKey == "exclusionShortcut" ? "ctrlOptK" : "ctrlOptR") }
    @objc func recordExclusionShortcut() { recordShortcut(key: "exclusionShortcut") }
    @objc func recordConversionShortcut() { recordShortcut(key: "convertSelectionShortcut") }
    func recordShortcut(key: String) {
        guard shortcutRecorder == nil, let parent = settingsWindow else { return }
        shortcutRecordingKey = key
        let sheet = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 190), styleMask: [.titled], backing: .buffered, defer: false)
        sheet.title = tr("Горячая клавиша", "Keyboard shortcut")
        let root = ContentView(frame: NSRect(x: 0, y: 0, width: 420, height: 190)); sheet.contentView = root
        let prompt = NSTextField(labelWithString: tr("Нажмите нужное сочетание клавиш", "Press your preferred keyboard shortcut"))
        prompt.frame = NSRect(x: 20, y: 20, width: 380, height: 28); prompt.alignment = .center; root.addSubview(prompt)
        let hint = NSTextField(wrappingLabelWithString: tr("Используйте ⌘, ⌃ или ⌥ вместе с любой клавишей. Можно добавить ⇧. Esc — отмена. Системные сочетания могут быть недоступны.", "Use ⌘, ⌃ or ⌥ with any key. You can add ⇧. Esc cancels. System shortcuts may be unavailable."))
        hint.frame = NSRect(x: 24, y: 58, width: 372, height: 62); hint.textColor = .secondaryLabelColor; root.addSubview(hint)
        for (title, x, width, action) in [(tr("Отмена", "Cancel"), CGFloat(20), CGFloat(90), #selector(cancelShortcutRecording)), (key == "exclusionShortcut" ? "⌃⌥K" : "⌃⌥R", CGFloat(120), CGFloat(80), #selector(resetShortcutRecording)), (tr("Отключить", "Disable"), CGFloat(210), CGFloat(190), #selector(disableShortcutRecording))] {
            let button = NSButton(title: title, target: self, action: action); button.bezelStyle = .rounded; button.frame = NSRect(x: x, y: 140, width: width, height: 28); root.addSubview(button)
        }
        shortcutRecorder = sheet
        shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak prompt] event in
            guard let self, self.shortcutRecorder != nil else { return event }
            if event.isARepeat { return nil }
            let flags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)).intersection(ExclusionShortcut.modifierMask)
            if event.keyCode == 53 && flags.isEmpty { self.finishShortcutRecording(nil); return nil }
            if let id = ExclusionShortcut.encode(key: Int64(event.keyCode), flags: flags) {
                let otherKey = key == "exclusionShortcut" ? "convertSelectionShortcut" : "exclusionShortcut"
                let other = UserDefaults.standard.string(forKey: otherKey) ?? (otherKey == "exclusionShortcut" ? "ctrlOptK" : "ctrlOptR")
                if ExclusionShortcut.matches(other, key: Int64(event.keyCode), flags: flags) {
                    prompt?.stringValue = self.tr("Это сочетание уже используется KiYo", "This shortcut is already used by KiYo")
                } else { self.finishShortcutRecording(id) }
            }
            else { prompt?.stringValue = self.tr("Добавьте ⌘, ⌃ или ⌥; ⌃⌥Space уже занято", "Add ⌘, ⌃ or ⌥; ⌃⌥Space is already used") }
            return nil
        }
        parent.beginSheet(sheet)
        sheet.makeKey()
    }
    func saveSelectedExclusions(_ text: String) -> Bool {
        let words = ExclusionRules.wordsFromSelection(text)
        guard !words.isEmpty else { return false }
        if testOutput != nil { testExcludedWords = excludedWords.union(words) }
        else { UserDefaults.standard.set(excludedWords.union(words).sorted(), forKey: "excludedWords") }
        buffer = ""
        return true
    }
    func selectionFeedback(_ success: Bool, conversion: Bool = false) {
        let hud = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 44), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        hud.level = .floating; hud.isOpaque = false; hud.backgroundColor = .windowBackgroundColor
        hud.hasShadow = true; hud.ignoresMouseEvents = true
        let message = conversion ? (success ? tr("Раскладка выделения исправлена", "Selected layout converted") : tr("Нет доступного выделения для правки", "No editable selection available")) : (success ? tr("Добавлено в исключения KiYo", "Added to KiYo exceptions") : tr("Нет доступного выделенного текста", "No accessible text selected"))
        let label = NSTextField(labelWithString: message)
        label.alignment = .center; label.frame = NSRect(x: 8, y: 12, width: 284, height: 20)
        hud.contentView?.addSubview(label); hud.center(); shortcutHUD?.orderOut(nil); shortcutHUD = hud; hud.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self, weak hud] in hud?.orderOut(nil); if self?.shortcutHUD === hud { self?.shortcutHUD = nil } }
    }
    func addSelectionWithShortcut(pid: pid_t) {
        if testOutput != nil { _ = saveSelectedExclusions(testSelection ?? ""); return }
        guard !shortcutBusy, NSWorkspace.shared.frontmostApplication?.processIdentifier == pid, !IsSecureEventInputEnabled(), !protectedField(pid: pid) else { return }
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.1)
        var focused: CFTypeRef?
        if AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &focused) == .success, let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() {
            let element = focused as! AXUIElement
            AXUIElementSetMessagingTimeout(element, 0.1)
            var selected: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selected) == .success, let text = selected as? String, !text.isEmpty {
                selectionFeedback(saveSelectedExclusions(text)); return
            }
        }
        // Some web views expose Copy but not AXSelectedText. Preserve every pasteboard format.
        let board = NSPasteboard.general
        var snapshotBytes = 0
        var saved: [[(NSPasteboard.PasteboardType, Data)]] = []
        for item in board.pasteboardItems ?? [] {
            var values: [(NSPasteboard.PasteboardType, Data)] = []
            for type in item.types {
                guard let data = item.data(forType: type) else { selectionFeedback(false); return }
                snapshotBytes += data.count
                guard snapshotBytes <= 8_388_608 else { selectionFeedback(false); return }
                values.append((type, data))
            }
            saved.append(values)
        }
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 8, keyDown: true), let up = CGEvent(keyboardEventSource: nil, virtualKey: 8, keyDown: false) else { selectionFeedback(false); return }
        let baseline = board.changeCount
        shortcutBusy = true
        for event in [down, up] {
            event.flags = .maskCommand
            event.setIntegerValueField(.eventSourceUserData, value: injectedTag)
            event.postToPid(pid)
        }
        func finish(_ attempts: Int) {
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid, !IsSecureEventInputEnabled() else { shortcutBusy = false; return }
            if board.changeCount == baseline && attempts > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { finish(attempts - 1) }; return }
            let copied = board.changeCount != baseline
            let text = copied ? board.string(forType: .string) : nil
            if copied {
                board.clearContents()
                let items = saved.map { values -> NSPasteboardItem in let item = NSPasteboardItem(); for (type, data) in values { item.setData(data, forType: type) }; return item }
                if !items.isEmpty { board.writeObjects(items) }
            }
            shortcutBusy = false
            selectionFeedback(saveSelectedExclusions(text ?? ""))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { finish(11) }
    }
    @objc func addToExceptions(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pasteboard.string(forType: .string) else { return }
        let words = ExclusionRules.wordsFromSelection(text)
        guard !words.isEmpty else { return }
        UserDefaults.standard.set(excludedWords.union(words).sorted(), forKey: "excludedWords")
        buffer = ""
    }
    func updateSyncStatus() {
        let message: String
        switch preferencesSync.status {
        case "ready": message = tr("Настройки сохранены в общей папке", "Settings saved in the shared folder")
        case "unavailable": message = tr("Папка недоступна. Проверьте iCloud Drive", "Folder unavailable. Check iCloud Drive")
        case "reconnect": message = tr("Выберите общую папку заново", "Select the shared folder again")
        case "tooLarge": message = tr("Слишком большой список исключений", "The exceptions list is too large")
        default: message = preferencesSync.connected ? tr("Подключение к общей папке…", "Connecting to the shared folder…") : tr("Выберите одну папку iCloud Drive на всех Mac", "Choose the same iCloud Drive folder on every Mac")
        }
        syncStatusLabel?.stringValue = message
        syncButton?.title = preferencesSync.connected ? tr("Отключить", "Disconnect") : tr("Подключить…", "Connect…")
    }
    func applySyncedPreferences() {
        enabled = UserDefaults.standard.object(forKey: "correctionEnabled") as? Bool ?? true
        buffer = ""
        animationTimer?.invalidate()
        animating = false
        expanded = false
        configurePresentation()
        positionPanel()
        configureAppMenu()
        render()
        refreshSettings()
        refreshWelcome()
        refreshAbout()
        refreshGuide()
    }
    @objc func configureSync() {
        if preferencesSync.connected {
            preferencesSync.disconnect()
            refreshSettings()
            return
        }
        guard let window = settingsWindow else { return }
        let picker = NSOpenPanel()
        picker.title = tr("Папка синхронизации KiYo", "KiYo sync folder")
        picker.message = tr("Выберите или создайте папку KiYo в iCloud Drive. На каждом Mac подключите ту же папку. Общими станут настройки и слова-исключения; разрешения и автозапуск остаются отдельными.", "Choose or create a KiYo folder in iCloud Drive. Select the same folder on every Mac. Settings and word exceptions are shared; permissions and login items remain local.")
        picker.canChooseDirectories = true
        picker.canChooseFiles = false
        picker.canCreateDirectories = true
        picker.allowsMultipleSelection = false
        picker.prompt = tr("Подключить", "Connect")
        picker.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, let url = picker.url else { return }
            self.preferencesSync.connect(url)
            self.refreshSettings()
        }
    }
    func activeLayoutIsRussian() -> Bool {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else { return false }
        let languages = Unmanaged<CFArray>.fromOpaque(pointer).takeUnretainedValue() as? [String] ?? []
        return languages.contains("ru")
    }
    func observeKeyboardLayout(_ russian: Bool, now: Date = Date()) {
        if let pending = pendingLayoutChange, now > pending.until { pendingLayoutChange = nil }
        let requested = pendingLayoutChange?.russian == russian
        if currentRussian != russian {
            currentRussian = russian
            // Our source change can be reported after the next letters arrive.
            // Only an external layout change invalidates the partially typed word.
            if !requested { buffer = ""; layoutBufferResets += 1 }
            if expanded && !animating { render() }
        }
        if requested { pendingLayoutChange = nil }
    }
    func checkMouse() {
        observeKeyboardLayout(activeLayoutIsRussian())
        guard expanded, !animating else { outsideSince = nil; return }
        if panel.frame.contains(NSEvent.mouseLocation) || (usesMenuBar && (statusItem?.button?.window?.frame.contains(NSEvent.mouseLocation) ?? false)) { outsideSince = nil }
        else if let since = outsideSince {
            if Date().timeIntervalSince(since) >= 2 { setExpanded(false) }
        } else { outsideSince = Date() }
    }
    func setExpanded(_ open: Bool) {
        guard !animating, open != expanded else { return }
        outsideSince = nil
        if usesMenuBar {
            expanded = open
            if open {
                positionPanel()
                render()
                panel.alphaValue = 0
                panel.orderFrontRegardless()
            }
            animating = true
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.16
                panel.animator().alphaValue = open ? 1 : 0
            }, completionHandler: { [weak self] in
                guard let self else { return }
                self.animating = false
                if !self.expanded { self.panel.orderOut(nil) }
            })
            return
        }
        let start = panel.frame
        expanded = open
        let end = targetFrame()
        if open { render(); content?.alphaValue = 0 }
        else { content?.removeFromSuperview(); content = nil; panel.contentView?.subviews.forEach { ($0 as? NSButton)?.image = nil } }
        animating = true
        let began = Date()
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let duration = reduceMotion ? 0.01 : 0.3
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let t = min(1, Date().timeIntervalSince(began) / duration)
            let eased = t * t * (3 - 2 * t)
            let h = start.height + (end.height - start.height) * eased
            self.panel.setFrame(NSRect(x: end.minX, y: end.maxY - h, width: end.width, height: h), display: true)
            self.panel.contentView?.needsDisplay = true
            if t >= 1 {
                timer.invalidate()
                self.animating = false
                self.render()
                if open {
                    self.content?.alphaValue = 0
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = reduceMotion ? 0 : 0.18
                        self.content?.animator().alphaValue = 1
                    }
                }
            }
        }
    }
    func configureAppMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "KiYo")
        for (title, action, key) in [
            (tr("О KiYo", "About KiYo"), #selector(showAbout), ""),
            (tr("Инструкция", "User guide"), #selector(showGuide), ""),
            (tr("Настройки…", "Settings…"), #selector(showSettings), ","),
            (tr("Завершить KiYo", "Quit KiYo"), #selector(quit), "q")
        ] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = self
            appMenu.addItem(item)
        }
        appItem.submenu = appMenu
        menu.addItem(appItem)
        NSApp.mainMenu = menu
    }
    @objc func showAbout() {
        if aboutWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 264), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            aboutWindow = window
        }
        refreshAbout()
        refreshGuide()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow?.makeKeyAndOrderFront(nil)
    }
    func refreshAbout() {
        guard let window = aboutWindow else { return }
        window.title = tr("О KiYo", "About KiYo")
        let root = ContentView(frame: NSRect(x: 0, y: 0, width: 420, height: 264))
        window.contentView = root
        let logo = NSImageView(frame: NSRect(x: 24, y: 20, width: 44, height: 44))
        logo.image = Bundle.main.image(forResource: "AppIcon") ?? notchLogo()
        root.addSubview(logo)
        func text(_ value: String, y: CGFloat, height: CGFloat, size: CGFloat = 13, bold: Bool = false) {
            let field = NSTextField(wrappingLabelWithString: value)
            field.frame = NSRect(x: 24, y: y, width: 372, height: height)
            field.font = .systemFont(ofSize: size, weight: bold ? .semibold : .regular)
            root.addSubview(field)
        }
        let name = NSTextField(labelWithString: "KiYo  " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"))
        name.frame = NSRect(x: 82, y: 30, width: 300, height: 28)
        name.font = .systemFont(ofSize: 20, weight: .semibold)
        root.addSubview(name)
        let developer = NSTextField(labelWithString: tr("Разработчик: Raven Systems", "Developed by Raven Systems"))
        let developerText = tr("Разработчик: Raven Systems", "Developed by Raven Systems")
        let linkedDeveloper = NSMutableAttributedString(string: developerText, attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor])
        linkedDeveloper.addAttributes([.link: URL(string: "https://ravensystems.io/")!, .foregroundColor: NSColor.linkColor], range: (developerText as NSString).range(of: "Raven Systems"))
        developer.attributedStringValue = linkedDeveloper
        developer.isSelectable = true
        developer.allowsEditingTextAttributes = true
        developer.frame = NSRect(x: 82, y: 59, width: 300, height: 18)
        root.addSubview(developer)
        text(tr("Автоматически исправляет слова, набранные в неверной русской или английской раскладке, и переключает язык ввода.", "Automatically corrects words typed in the wrong Russian or English keyboard layout and switches the input language."), y: 84, height: 58)
        text(tr("Текст обрабатывается локально на вашем Mac.", "Text is processed locally on your Mac."), y: 150, height: 24, size: 11)
        let privacy = NSButton(title: tr("Конфиденциальность", "Privacy"), target: self, action: #selector(showPrivacy))
        privacy.bezelStyle = .rounded; privacy.frame = NSRect(x: 24, y: 182, width: 180, height: 28); root.addSubview(privacy)
        let notices = NSButton(title: tr("Компоненты и права", "Components and rights"), target: self, action: #selector(showNotices))
        notices.bezelStyle = .rounded; notices.frame = NSRect(x: 216, y: 182, width: 180, height: 28); root.addSubview(notices)
        let close = NSButton(title: tr("Понятно", "Done"), target: window, action: #selector(NSWindow.performClose(_:)))
        close.bezelStyle = .rounded
        close.keyEquivalent = "\r"
        close.frame = NSRect(x: 292, y: 224, width: 104, height: 28)
        root.addSubview(close)
    }
    @objc func showPrivacy() { showDocument("Privacy", title: tr("Конфиденциальность KiYo", "KiYo privacy")) }
    @objc func showNotices() { showDocument("Notices", title: tr("Компоненты и права", "Components and rights")) }
    func showDocument(_ resource: String, title: String) {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent(language + ".lproj/" + resource + ".txt"), let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        let window: NSWindow
        if let existing = documentWindows[resource] { window = existing }
        else {
            window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 460), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.delegate = self; window.center(); window.minSize = NSSize(width: 420, height: 300)
            documentWindows[resource] = window
        }
        window.title = title
        let scroll = NSScrollView(frame: NSRect(origin: .zero, size: window.contentLayoutRect.size)); scroll.autoresizingMask = [.width, .height]; scroll.hasVerticalScroller = true
        let editor = NSTextView(frame: scroll.bounds)
        editor.isRichText = false; editor.isEditable = false; editor.isSelectable = true
        editor.isVerticallyResizable = true; editor.isHorizontallyResizable = false; editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true; editor.textContainerInset = NSSize(width: 18, height: 18)
        editor.font = .systemFont(ofSize: 13); editor.string = text
        scroll.documentView = editor; window.contentView = scroll
        NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil)
    }
    @objc func showGuide() {
        if guideWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 580), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.delegate = self; window.center(); guideWindow = window
        }
        refreshGuide()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        guideWindow?.makeKeyAndOrderFront(nil)
    }
    func refreshGuide() {
        guard let window = guideWindow else { return }
        window.title = tr("Инструкция KiYo", "KiYo user guide")
        let root = ContentView(frame: NSRect(x: 0, y: 0, width: 480, height: 580)); window.contentView = root
        let sections: [(String, String)] = [
            (tr("Начало работы", "Getting started"), tr("Разрешите KiYo доступ в macOS → Конфиденциальность и безопасность → Универсальный доступ. Печатайте как обычно: слова исправляются после пробела.", "Allow KiYo in macOS → Privacy & Security → Accessibility. Type normally: words are corrected after a space.")),
            (tr("Раскладка и орфография", "Keyboard layout and spelling"), tr("Автоисправление меняет неверную русскую или английскую раскладку. Для опечаток включите «Исправление орфографии». ⌃⌥Пробел исправляет текущее слово вручную. Чтобы исправить целую фразу, выделите её и нажмите сочетание «Исправить выделение» (по умолчанию ⌃⌥R).", "Auto correction fixes the wrong Russian or English layout. Enable Spelling correction to fix typos. ⌃⌥Space corrects the current word manually. Select a phrase and press Convert selection (default ⌃⌥R) to convert its layout.")),
            (tr("Исключения и горячая клавиша", "Exceptions and keyboard shortcut"), tr("В настройках нажмите сочетание в строке «Добавить выделение» и задайте своё. Затем выделите текст в приложении и нажмите это сочетание. Эти слова больше не будут исправляться. Список доступен в «Слова-исключения».", "In Settings, click the shortcut next to Add selection and record your own. Then select text in an app and press the shortcut. Those words will no longer be corrected. Manage the list under Excluded words.")),
            (tr("Расположение и пауза", "Location and pause"), tr("Значок открывает панель KiYo. Шестерёнка открывает настройки, кнопка паузы останавливает автоисправление. В «Отображение» выберите чёлку или строку меню; на Mac без чёлки используется строка меню.", "Click the icon to open KiYo. The gear opens Settings; Pause stops auto correction. Display mode lets you choose the notch or menu bar. Macs without a notch use the menu bar.")),
            (tr("Синхронизация", "Sync"), tr("Подключите одну и ту же папку KiYo в iCloud Drive на каждом Mac. Настройки и исключения синхронизируются. Доступ macOS и запуск при входе настраиваются на каждом устройстве отдельно.", "Connect the same KiYo folder in iCloud Drive on each Mac to sync settings and exceptions. Set up macOS permissions and launch at login separately on each device."))
        ]
        var y: CGFloat = 20
        for (heading, body) in sections {
            let title = NSTextField(labelWithString: heading); title.font = .systemFont(ofSize: 13, weight: .semibold); title.frame = NSRect(x: 24, y: y, width: 432, height: 20); root.addSubview(title)
            let text = NSTextField(wrappingLabelWithString: body); text.font = .systemFont(ofSize: 12); text.textColor = .secondaryLabelColor; text.frame = NSRect(x: 24, y: y + 26, width: 432, height: 66); root.addSubview(text)
            y += 104
        }
        let close = NSButton(title: tr("Понятно", "Done"), target: window, action: #selector(NSWindow.performClose(_:))); close.bezelStyle = .rounded; close.keyEquivalent = "\r"; close.frame = NSRect(x: 352, y: 542, width: 104, height: 28); root.addSubview(close)
    }
    func showWelcome() {
        if welcomeWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 408), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.titleVisibility = .hidden
            window.center()
            welcomeWindow = window
        }
        refreshWelcome()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        welcomeWindow?.makeKeyAndOrderFront(nil)
    }
    func refreshWelcome() {
        guard let window = welcomeWindow else { return }
        let root = ContentView(frame: NSRect(x: 0, y: 0, width: 420, height: 408))
        window.contentView = root
        let icon = NSImageView(frame: NSRect(x: 190, y: 12, width: 40, height: 40))
        icon.image = notchLogo()
        icon.contentTintColor = .labelColor
        icon.imageScaling = .scaleProportionallyUpOrDown
        root.addSubview(icon)
        func text(_ value: String, y: CGFloat, height: CGFloat, size: CGFloat = 13, centered: Bool = false) {
            let field = NSTextField(wrappingLabelWithString: value)
            field.frame = NSRect(x: 24, y: y, width: 372, height: height)
            field.font = .systemFont(ofSize: size, weight: size > 16 ? .semibold : .regular)
            field.alignment = centered ? .center : .left
            root.addSubview(field)
        }
        text(tr("Добро пожаловать в KiYo", "Welcome to KiYo"), y: 62, height: 28, size: 21, centered: true)
        text(tr("По умолчанию значок KiYo находится справа возле часов. В настройках можно выбрать чёлку. Нажмите на него, чтобы открыть панель. Шестерёнка открывает настройки.", "By default, find KiYo on the right near the clock. You can choose the notch in Settings. Click the icon to open the panel. The gear opens Settings."), y: 100, height: 65)
        text(tr("Язык приложения", "App language"), y: 180, height: 24)
        let languages = NSPopUpButton(frame: NSRect(x: 218, y: 174, width: 178, height: 32))
        languages.addItems(withTitles: [tr("Системный", "System default"), "Русский", "English"])
        languages.selectItem(at: ["system", "ru", "en"].firstIndex(of: UserDefaults.standard.string(forKey: "language") ?? "system") ?? 0)
        languages.target = self; languages.action = #selector(changeLanguage(_:))
        root.addSubview(languages)
        text(tr("Расположение значка", "Icon location"), y: 222, height: 24)
        let location = NSPopUpButton(frame: NSRect(x: 218, y: 216, width: 178, height: 32))
        location.addItems(withTitles: language == "en" ? ["Automatic", "In the notch", "In the status bar"] : ["Автоматически", "В чёлке", "В статус-баре"])
        location.selectItem(at: ["automatic", "notch", "menubar"].firstIndex(of: presentationPreference) ?? 0)
        location.target = self; location.action = #selector(changePresentation(_:))
        root.addSubview(location)
        text(tr("Запускать при входе в macOS", "Launch at login"), y: 266, height: 24)
        let login = NSSwitch(frame: NSRect(x: 350, y: 260, width: 46, height: 30))
        login.state = loginEnabled ? .on : .off
        login.target = self; login.action = #selector(toggleLogin)
        login.setAccessibilityLabel(tr("Запускать при входе в macOS", "Launch at login"))
        root.addSubview(login)
        text(tr("Эти параметры можно изменить позже в настройках. На Mac без чёлки значок появится в строке меню.", "You can change these options later in Settings. Macs without a notch use the menu bar."), y: 312, height: 38, size: 11)
        let settings = NSButton(title: tr("Настройки", "Settings"), target: self, action: #selector(welcomeSettings))
        settings.bezelStyle = .rounded
        settings.frame = NSRect(x: 24, y: 364, width: 112, height: 28)
        root.addSubview(settings)
        let start = NSButton(title: tr("Начать", "Get started"), target: self, action: #selector(finishWelcome))
        start.bezelStyle = .rounded
        start.keyEquivalent = "\r"
        start.frame = NSRect(x: 284, y: 364, width: 112, height: 28)
        root.addSubview(start)
    }
    @objc func finishWelcome() {
        UserDefaults.standard.set(true, forKey: "welcomeCompleted")
        welcomeWindow?.close()
        welcomeWindow = nil
    }
    @objc func welcomeSettings() { finishWelcome(); showSettings() }
    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let hasOpenWindow = [self.settingsWindow, self.aboutWindow, self.guideWindow, self.welcomeWindow].contains { $0?.isVisible == true } || self.documentWindows.values.contains { $0.isVisible }
            if !hasOpenWindow { NSApp.setActivationPolicy(.accessory) }
        }
    }
    func revealInterface() {
        if let window = welcomeWindow, window.isVisible {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        } else { showSettings() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // The notch is a visible NSPanel, but it must not swallow Finder reopen.
        revealInterface()
        return true
    }
    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 626), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        refreshSettings()
        setExpanded(false)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func expand() { setExpanded(!expanded) }
    @objc func toggleEnabled() { enabled.toggle(); UserDefaults.standard.set(enabled, forKey: "correctionEnabled"); buffer = ""; render(); refreshSettings() }
    @objc func changePresentation(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(["automatic", "notch", "menubar"][sender.indexOfSelectedItem], forKey: "presentation")
        animationTimer?.invalidate()
        animating = false
        expanded = false
        outsideSince = nil
        configurePresentation()
        positionPanel()
        render()
        refreshSettings()
        refreshWelcome()
    }
    @objc func changeLanguage(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(["system", "ru", "en"][sender.indexOfSelectedItem], forKey: "language")
        configureAppMenu()
        refreshAbout()
        refreshGuide()
        render()
        refreshSettings()
        refreshWelcome()
    }
    @objc func changeSensitivity(_ sender: NSSegmentedControl) {
        UserDefaults.standard.set(sender.selectedSegment, forKey: "sensitivity")
    }
    @objc func toggleSpelling() {
        UserDefaults.standard.set(!spellingEnabled, forKey: "spellingEnabled")
        refreshSettings()
    }
    @objc func toggleShort() {
        UserDefaults.standard.set(!shortWords, forKey: "shortWords")
        render()
        refreshSettings()
    }
    @objc func toggleLogin() {
        do {
            if loginEnabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
            if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch {
            let alert = NSAlert()
            alert.messageText = tr("Не удалось изменить автозапуск", "Could not change launch at login")
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        render()
        refreshSettings()
        refreshWelcome()
    }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func permissions() {
        startListening(prompt: false)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"), NSWorkspace.shared.open(url) { return }
        let alert = NSAlert()
        alert.messageText = tr("Откройте Универсальный доступ", "Open Accessibility settings")
        alert.informativeText = tr("Системные настройки → Конфиденциальность и безопасность → Универсальный доступ → KiYo.", "System Settings → Privacy & Security → Accessibility → KiYo.")
        alert.runModal()
    }
    func writeHealth() {
        guard CommandLine.arguments.contains("--diagnostics") else { return }
        let health: [String: Any] = ["accessibility": AXIsProcessTrusted(), "eventTap": tap != nil, "secureInput": IsSecureEventInputEnabled(), "pid": ProcessInfo.processInfo.processIdentifier, "observedKeys": observedKeys, "observedLetters": observedLetters, "corrections": corrections, "layoutChanges": layoutChanges, "enabled": enabled, "bufferLength": buffer.count, "callbackMaximumMS": callbackMaximumMS, "tapTimeouts": tapTimeouts, "eventTapEnabled": tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false, "layoutBufferResets": layoutBufferResets, "pendingAutomaticLayout": pendingLayoutChange != nil, "skippedReasons": skippedReasons]
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let folder = base.appendingPathComponent("local.kiyo.switchet", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let info = try folder.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
            guard info.isSymbolicLink != true, info.isDirectory == true else { return }
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
            let data = try JSONSerialization.data(withJSONObject: health, options: [.prettyPrinted])
            let destination = folder.appendingPathComponent("health.json")
            try data.write(to: destination, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        } catch { /* Diagnostics are optional and must never affect typing. */ }
    }
    func startListening(prompt: Bool) {
        defer { writeHealth() }
        guard tap == nil else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else { return }
        let mask = [CGEventType.keyDown, .leftMouseDown, .rightMouseDown].reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { proxy, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            let app = Unmanaged<App>.fromOpaque(info).takeUnretainedValue()
            return app.handle(type: type, event: event, proxy: proxy) ? nil : Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        if let tap {
            CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0), .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        render()
        refreshSettings()
    }
    func handle(type: CGEventType, event: CGEvent, proxy: CGEventTapProxy?) -> Bool {
        let started = DispatchTime.now().uptimeNanoseconds
        defer {
            callbackMaximumMS = max(callbackMaximumMS, Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000)
        }
        activeEventProxy = proxy
        defer { activeEventProxy = nil }
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if type == .tapDisabledByTimeout { tapTimeouts += 1 }
            buffer = ""
            ignoringLongToken = false
            correctionRejections.cancel()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        if event.getIntegerValueField(.eventSourceUserData) == injectedTag { return false }
        if type == .keyUp { return false }
        selectionEpoch &+= 1
        if type != .keyDown { buffer = ""; ignoringLongToken = false; correctionRejections.cancel(); return false }
        if shortcutRecorder != nil { buffer = ""; ignoringLongToken = false; correctionRejections.cancel(); return false }
        observedKeys += 1
        if event.getIntegerValueField(.keyboardEventKeycode) != 51 || !event.flags.intersection([.maskControl, .maskCommand, .maskAlternate]).isEmpty { correctionRejections.cancel() }
        let shortcutPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
        if ExclusionShortcut.matches(testConversionShortcutID ?? UserDefaults.standard.string(forKey: "convertSelectionShortcut") ?? "ctrlOptR", key: event.getIntegerValueField(.keyboardEventKeycode), flags: event.flags) {
            buffer = ""
            ignoringLongToken = false
            guard !IsSecureEventInputEnabled(), !protectedField(pid: shortcutPID) else { return false }
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                if testOutput != nil { convertSelectionWithShortcut(pid: shortcutPID) }
                else { DispatchQueue.main.async { [weak self] in self?.convertSelectionWithShortcut(pid: shortcutPID) } }
            }
            return true
        }
        if ExclusionShortcut.matches(testShortcutID ?? UserDefaults.standard.string(forKey: "exclusionShortcut") ?? "ctrlOptK", key: event.getIntegerValueField(.keyboardEventKeycode), flags: event.flags) {
            buffer = ""
            ignoringLongToken = false
            guard !IsSecureEventInputEnabled(), !protectedField(pid: shortcutPID) else { return false }
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                if testOutput != nil { addSelectionWithShortcut(pid: shortcutPID) }
                else { DispatchQueue.main.async { [weak self] in self?.addSelectionWithShortcut(pid: shortcutPID) } }
            }
            return true
        }
        guard enabled, !replacing else { recordSkip(enabled ? "replacing" : "paused"); buffer = ""; ignoringLongToken = false; return false }
        let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
        if lastPID != pid { buffer = ""; ignoringLongToken = false; correctionRejections.cancel(); lastPID = pid }
        if IsSecureEventInputEnabled() || protectedField(pid: pid) { recordSkip("protectedOrUnavailableField"); buffer = ""; ignoringLongToken = false; correctionRejections.cancel(); return false }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate])
        if key == 49 && flags == [.maskControl, .maskAlternate] {
            guard !buffer.isEmpty else { return false }
            return replace(with: LayoutConverter.convert(buffer), suffix: "", pid: pid)
        }
        guard flags.isEmpty else { recordSkip("modifierShortcut"); buffer = ""; ignoringLongToken = false; return false }
        if key == 51 { if let original = correctionRejections.backspace(pid: pid) { selectLayout(russian: LayoutConverter.russian(original)) }; if !ignoringLongToken && !buffer.isEmpty { buffer.removeLast() }; return false }
        var chars = [UniChar](repeating: 0, count: 16)
        var length = 0
        event.keyboardGetUnicodeString(maxStringLength: chars.count, actualStringLength: &length, unicodeString: &chars)
        let text = length > 0 ? String(utf16CodeUnits: chars, count: length) : translatedKey(event)
        if [" ", "\n", "\r", "\t"].contains(text) {
            if ignoringLongToken { buffer = ""; ignoringLongToken = false; return false }
            let minimum = sensitivity == 0 ? 4 : 2
            let preserving = correctionRejections.consumePreservation(buffer)
            let protected = ExclusionRules.protectedToken(buffer, words: excludedWords)
            if !preserving && !protected {
                if buffer.count >= minimum, (shortWords || buffer.count >= 3), let fixed = LayoutConverter.correction(buffer, sensitivity: sensitivity) {
                    return replace(with: fixed, suffix: text, pid: pid, changeLayout: LayoutConverter.russian(fixed) != LayoutConverter.russian(buffer), delimiter: event)
                }
                if spellingEnabled, let fixed = SystemSpelling.correction(buffer), !ExclusionRules.protectedToken(fixed, words: excludedWords) {
                    return replace(with: fixed, suffix: text, pid: pid, changeLayout: false, delimiter: event)
                }
            }
            if !buffer.isEmpty { recordSkip(preserving ? "retryPreserved" : protected ? "excludedOrAddress" : "noSuggestion") }
            buffer = ""
            ignoringLongToken = false
        } else if !text.isEmpty && text.unicodeScalars.allSatisfy({ !CharacterSet.whitespacesAndNewlines.contains($0) && !CharacterSet.controlCharacters.contains($0) }) {
            observedLetters += text.count
            if !ignoringLongToken { buffer += text }
            if buffer.count > 64 { buffer = ""; ignoringLongToken = true }
        } else { buffer = "" }
        return false
    }
    func translatedKey(_ event: CGEvent) -> String {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return "" }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return "" }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        var deadKey: UInt32 = 0
        var count = 0
        var output = [UniChar](repeating: 0, count: 16)
        var modifiers: UInt32 = 0
        if event.flags.contains(.maskShift) { modifiers |= UInt32(shiftKey >> 8) }
        if event.flags.contains(.maskAlphaShift) { modifiers |= UInt32(alphaLock >> 8) }
        let result = UCKeyTranslate(layout, UInt16(event.getIntegerValueField(.keyboardEventKeycode)), UInt16(kUCKeyActionDown), modifiers, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKey, output.count, &count, &output)
        return result == noErr ? String(utf16CodeUnits: output, count: count) : ""
    }
    @discardableResult
    func replace(with text: String, suffix: String, pid: pid_t, changeLayout: Bool = true, delimiter: CGEvent? = nil) -> Bool {
        let original = buffer
        buffer = ""
        guard testOutput != nil || NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return false }
        // Prepare the entire replacement before removing any original text.
        var events: [CGEvent] = []
        for _ in original {
            for down in [true, false] {
                guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 51, keyDown: down) else { return false }
                events.append(event)
            }
        }
        let units = Array((text + (delimiter == nil ? suffix : "")).utf16)
        guard let insert = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true), let release = insert.copy() else { return false }
        for event in [insert, release] {
            event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        }
        release.type = .keyUp
        events += [insert, release]
        var delimiterCopy: CGEvent?
        if let delimiter {
            guard let copy = delimiter.copy() else { return false }
            delimiterCopy = copy
            events.append(copy)
        }
        replacing = true
        defer { replacing = false }
        for event in events {
            if event !== delimiterCopy { event.flags = [] }
            event.setIntegerValueField(.eventSourceUserData, value: injectedTag)
            emit(event)
        }
        if suffix == " " { correctionRejections.record(word: original, outputCount: text.count + 1, pid: pid, restoreLayout: changeLayout) }
        corrections += 1
        lastOriginal = original
        lastCorrected = text
        if changeLayout { selectLayout(russian: LayoutConverter.russian(text)) }
        notice = "Исправлено: \(text)"
        if suffix.isEmpty { buffer = text }
        if expanded { DispatchQueue.main.async { [weak self] in self?.render() } }
        return true
    }
    func emit(_ event: CGEvent) {
        if let testOutput { testOutput(event); return }
        if let proxy = activeEventProxy { event.tapPostEvent(proxy) }
        else { event.post(tap: .cgSessionEventTap) }
    }
    func selectLayout(russian: Bool) {
        if testOutput != nil { testRussian = russian; pendingLayoutChange = (russian, Date().addingTimeInterval(2)); return }
        let filter = [kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String, kTISPropertyInputSourceIsSelectCapable as String: true] as CFDictionary
        let sources = TISCreateInputSourceList(filter, false).takeRetainedValue() as! [TISInputSource]
        for source in sources {
            guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else { continue }
            let languages = Unmanaged<CFArray>.fromOpaque(ptr).takeUnretainedValue() as! [String]
            if languages.contains(russian ? "ru" : "en") {
                if TISSelectInputSource(source) == noErr { pendingLayoutChange = (russian, Date().addingTimeInterval(2)); layoutChanges += 1 }
                return
            }
        }
    }
}

func runApplication() {
    let application = NSApplication.shared
    let delegate = App()
    do {
        delegate.instanceLock = try SingleInstanceLock.acquire()
        delegate.secondaryInstance = delegate.instanceLock == nil
    } catch { delegate.startupError = error }
    application.delegate = delegate
    withExtendedLifetime(delegate) { application.run() }
}

#if KIYO_TESTING
if CommandLine.arguments.contains("--instance-probe") {
    runInstanceProbe()
} else if CommandLine.arguments.contains("--launch-test") {
    runLaunchTests()
} else if CommandLine.arguments.contains("--sync-test") {
    runSyncTests()
} else if CommandLine.arguments.contains("--stress-test") {
    runTypingStressTests()
} else if CommandLine.arguments.contains("--self-test") {
    assert(SystemSpelling.bestSuggestion("праивльно", candidates: ["правильное", "правильно", "правильной"]) == "правильно")
    assert(SystemSpelling.bestSuggestion("поставвить", candidates: ["поставить"]) == "поставить")
    assert(SystemSpelling.bestSuggestion("котт", candidates: ["кот", "коты"]) == nil)
    let custom = ExclusionShortcut.encode(key: 35, flags: [.maskCommand, .maskShift])!
    assert(ExclusionShortcut.valid(custom))
    assert(ExclusionShortcut.matches(custom, key: 35, flags: [.maskCommand, .maskShift, .maskAlphaShift]))
    assert(!ExclusionShortcut.matches(custom, key: 35, flags: [.maskCommand]))
    assert(ExclusionShortcut.encode(key: 35, flags: []) == nil)
    assert(ExclusionShortcut.encode(key: 35, flags: [.maskShift]) == nil)
    assert(ExclusionShortcut.encode(key: 49, flags: [.maskControl, .maskAlternate]) == nil)
    assert(!ExclusionShortcut.valid("custom:999:0"))
    assert(!ExclusionShortcut.valid("custom:40:18446744073709551615"))
    assert(ExclusionShortcut.matches("ctrlOptK", key: 40, flags: [.maskControl, .maskAlternate]))
    assert(!ExclusionShortcut.matches("ctrlOptK", key: 40, flags: [.maskControl, .maskAlternate, .maskShift]))
    assert(!ExclusionShortcut.matches("off", key: 40, flags: [.maskControl, .maskAlternate]))
    assert(AppLanguage.resolve(nil, preferred: ["ru-RU", "en-US"]) == "ru")
    assert(AppLanguage.resolve(nil, preferred: ["en-GB", "ru-RU"]) == "en")
    assert(AppLanguage.resolve(nil, preferred: ["ru_UZ"]) == "ru")
    assert(AppLanguage.resolve(nil, preferred: ["uz-Latn-UZ", "de-DE"]) == "en")
    assert(AppLanguage.resolve("en", preferred: ["ru-RU"]) == "en")
    assert(AppLanguage.resolve("ru", preferred: ["en-US"]) == "ru")
    assert(AppLanguage.resolve("system", preferred: ["en-US"]) == "en")
    for (typed, expected) in [("рш", "hi"), ("рщц", "how"), ("фку", "are"), ("нщг", "you"), ("ghbdtn", "привет")] {
        assert(LayoutConverter.correction(typed) == expected)
    }
    for acronym in ["EN", "RU", "UZ", "EZ", "EU", "US", "GB", "DE", "FR", "IT", "ES", "JP", "CN", "CRM", "ERP", "API", "SQL", "HTML", "JSON", "VPN", "crm"] {
        assert(LayoutConverter.correction(LayoutConverter.convert(acronym)) == acronym, "Acronym failed: \(acronym)")
        assert(LayoutConverter.correction(acronym) == nil)
    }
    for term in ["postgres", "PostgreSQL", "Python", "javascript", "Docker", "git", "backend", "frontend", "kubernetes", "NodeJS", "API"] {
        assert(LayoutConverter.correction(LayoutConverter.convert(term)) == term)
        assert(LayoutConverter.correction(term) == nil)
    }
    for word in ["Лшнщ", "ЛшНщ", "лшнщ", "ЛШНЩ"] { assert(LayoutConverter.correction(word) == "KiYo") }
    assert(LayoutConverter.correction("KiYo") == nil)
    for spelling in ["kiyo", "KIYO", "Kiyo", "kIyO", "kiYO"] { assert(LayoutConverter.correction(spelling) == "KiYo") }
    assert(LayoutConverter.correction("ЛшНщ,") == "KiYo,")
    assert(LayoutConverter.correction("знещт") == "python")
    for spelling in ["РУ", "ру", "Ру"] { assert(LayoutConverter.correction(spelling) == nil) }
    assert(LayoutConverter.correction("НЕ") == nil)
    assert(LayoutConverter.correction("ТУ") == nil)
    assert(LayoutConverter.correction("не") == nil)
    assert(LayoutConverter.correction("ту") == nil)
    assert(LayoutConverter.correction("СКЬ,") == "CRM,")
    assert(LayoutConverter.correction("hi") == nil)
    assert(LayoutConverter.correction("привет") == nil)
    assert(LayoutConverter.convert("рш рщц фку нщг") == "hi how are you")
    assert(LayoutConverter.convert("ghbdtn") == "привет")
    assert(LayoutConverter.convert("руддщ") == "hello")
    assert(LayoutConverter.convert("Ghbdtn") == "Привет")
    assert(LayoutConverter.convert("Привет") == "Ghbdtn")
    print("Layout conversion checks passed")
} else {
    runApplication()
}

#else
runApplication()
#endif
