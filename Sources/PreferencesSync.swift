import AppKit

// Only these preferences are portable. Permissions, login items and machine state stay local.
enum SyncValue: Codable, Equatable {
    case string(String), boolean(Bool), integer(Int)
}
struct SyncEntry: Codable, Equatable {
    var value: SyncValue
    var modified: Double
    var writer: String
}
struct SyncDocument: Codable {
    var schema = 1
    var device: String
    var entries: [String: SyncEntry]
}
enum SyncRules {
    static func wordKey(_ word: String) -> String { "word:" + Data(word.utf8).base64EncodedString() }
    static func word(_ key: String) -> String? {
        guard key.hasPrefix("word:"), let data = Data(base64Encoded: String(key.dropFirst(5))), let value = String(data: data, encoding: .utf8), !value.isEmpty, value.count <= 64, !value.contains(where: { $0.isWhitespace }), value == ExclusionRules.normalize(value), !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
        return value
    }
    static func valid(_ key: String, _ entry: SyncEntry) -> Bool {
        guard entry.modified.isFinite, entry.modified >= 0, entry.modified <= Date().timeIntervalSince1970 + 300, !entry.writer.isEmpty, entry.writer.count <= 128 else { return false }
        switch (key, entry.value) {
        case ("language", .string(let value)): return ["system", "ru", "en"].contains(value)
        case ("presentation", .string(let value)): return ["automatic", "notch", "menubar"].contains(value)
        case ("exclusionShortcut", .string(let value)): return ExclusionShortcut.valid(value)
        case ("sensitivity", .integer(let value)): return (0...2).contains(value)
        case ("shortWords", .boolean), ("spellingEnabled", .boolean), ("correctionEnabled", .boolean): return true
        default: if case .boolean = entry.value { return word(key) != nil }; return false
        }
    }
    static func merge(_ local: [String: SyncEntry], _ incoming: [String: SyncEntry]) -> [String: SyncEntry] {
        var result = local.filter { valid($0.key, $0.value) }
        for (key, entry) in incoming where valid(key, entry) {
            if let old = result[key], old.modified > entry.modified || (old.modified == entry.modified && old.writer >= entry.writer) { continue }
            result[key] = entry
        }
        return result
    }
}

private final class SyncConnectionToken {
    private let lock = NSLock()
    private var stopped = false
    func cancel() { lock.lock(); stopped = true; lock.unlock() }
    var cancelled: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
}

final class PreferencesSync {
    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "io.ravensystems.kiyo.preferences", qos: .utility)
    private var entries: [String: SyncEntry] = [:]
    private var folder: URL?
    private var connectionToken = SyncConnectionToken()
    private var busy = false
    private var applying = false
    private var initialized = false
    private var connectionBaseline: [String: SyncValue] = [:]
    private var connectionWords: Set<String> = []
    private var observer: NSObjectProtocol?
    private var timer: Timer?
    private let device: String
    var onApply: (() -> Void)?
    var onStatus: (() -> Void)?
    private(set) var status = "off"
    var connected: Bool { folder != nil }
    var isWorking: Bool { busy }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        device = defaults.string(forKey: "syncDeviceID") ?? UUID().uuidString
        defaults.set(device, forKey: "syncDeviceID")
        if let data = defaults.data(forKey: "syncCachedEntries"), let cached = try? JSONDecoder().decode(SyncDocument.self, from: data), cached.schema == 1 { entries = SyncRules.merge([:], cached.entries) }
    }
    deinit {
        connectionToken.cancel()
        if let observer { NotificationCenter.default.removeObserver(observer) }
        timer?.invalidate()
        folder?.stopAccessingSecurityScopedResource()
    }
    func start() {
        observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: defaults, queue: .main) { [weak self] _ in
            guard let self, !self.applying, self.initialized || !self.entries.isEmpty else { return }
            self.captureLocal(force: true)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.refresh() }
        if let bookmark = defaults.data(forKey: "syncFolderBookmark") {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale) {
                connect(url)
            } else { status = "reconnect" }
        }
    }
    func connect(_ url: URL) {
        if !entries.isEmpty { captureLocal(force: true) }
        connectionToken.cancel()
        connectionToken = SyncConnectionToken()
        busy = false
        status = "connecting"
        folder?.stopAccessingSecurityScopedResource()
        folder = url
        _ = url.startAccessingSecurityScopedResource()
        initialized = false
        connectionBaseline = snapshot()
        connectionWords = Set((defaults.stringArray(forKey: "excludedWords") ?? []).map(ExclusionRules.normalize))
        if let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) { defaults.set(bookmark, forKey: "syncFolderBookmark") }
        onStatus?()
        refresh()
    }
    func disconnect() {
        connectionToken.cancel()
        busy = false
        folder?.stopAccessingSecurityScopedResource()
        folder = nil
        initialized = false
        defaults.removeObject(forKey: "syncFolderBookmark")
        status = "off"
        onStatus?()
    }
    private func cache() {
        if let data = try? JSONEncoder().encode(SyncDocument(device: device, entries: entries)) {
            if defaults.data(forKey: "syncCachedEntries") != data { defaults.set(data, forKey: "syncCachedEntries") }
        }
    }
    private func snapshot() -> [String: SyncValue] {
        ["exclusionShortcut": .string(defaults.string(forKey: "exclusionShortcut") ?? "ctrlOptK"),
         "language": .string(defaults.string(forKey: "language") ?? "system"),
         "presentation": .string(defaults.string(forKey: "presentation") ?? "automatic"),
         "sensitivity": .integer(defaults.object(forKey: "sensitivity") as? Int ?? 1),
         "shortWords": .boolean(defaults.object(forKey: "shortWords") as? Bool ?? true),
         "spellingEnabled": .boolean(defaults.bool(forKey: "spellingEnabled")),
         "correctionEnabled": .boolean(defaults.object(forKey: "correctionEnabled") as? Bool ?? true)]
    }
    private func captureLocal(force: Bool = false) {
        guard (initialized || force), !applying else { return }
        var changed = false
        func record(_ key: String, _ value: SyncValue) {
            guard entries[key]?.value != value else { return }
            let previous = entries[key]?.modified ?? 0
            entries[key] = SyncEntry(value: value, modified: max(Date().timeIntervalSince1970, previous + 0.000001), writer: device)
            changed = true
        }
        for (key, value) in snapshot() { record(key, value) }
        let words = Set((defaults.stringArray(forKey: "excludedWords") ?? []).map(ExclusionRules.normalize))
        for word in words where !word.isEmpty && word.count <= 64 && !word.contains(where: { $0.isWhitespace }) { record(SyncRules.wordKey(word), .boolean(true)) }
        for key in Array(entries.keys) {
            if let word = SyncRules.word(key), !words.contains(word) { record(key, .boolean(false)) }
        }
        if changed { cache() }
    }
    private func apply() -> Bool {
        applying = true
        defer { applying = false }
        var changed = false
        for (key, entry) in entries where !key.hasPrefix("word:") {
            let value: Any
            switch entry.value {
            case .string(let item): value = item
            case .boolean(let item): value = item
            case .integer(let item): value = item
            }
            if (defaults.object(forKey: key) as? NSObject)?.isEqual(value) != true { defaults.set(value, forKey: key); changed = true }
        }
        let words = entries.compactMap { key, entry -> String? in
            guard case .boolean(true) = entry.value else { return nil }
            return SyncRules.word(key)
        }.sorted()
        if defaults.stringArray(forKey: "excludedWords") ?? [] != words { defaults.set(words, forKey: "excludedWords"); changed = true }
        return changed
    }
    func refresh() {
        guard let folder, !busy else { return }
        if initialized { captureLocal() }
        busy = true
        let connection = folder
        let token = connectionToken
        queue.async { [weak self] in
            do {
                guard !token.cancelled else { return }
                let urls = try FileManager.default.contentsOfDirectory(at: connection, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles]).filter { $0.lastPathComponent.hasPrefix("KiYo-settings-") && $0.pathExtension == "json" }
                guard urls.count <= 1000 else { throw CocoaError(.fileReadTooLarge) }
                var documents: [SyncDocument] = []
                var totalBytes = 0
                var totalEntries = 0
                for url in urls {
                    guard !token.cancelled else { return }
                    let attributes = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
                    guard attributes.isRegularFile == true, attributes.isSymbolicLink != true, (attributes.fileSize ?? 0) <= 1_048_576 else { continue }
                    totalBytes += attributes.fileSize ?? 0
                    guard totalBytes <= 8_388_608 else { throw CocoaError(.fileReadTooLarge) }
                    var coordinationError: NSError?
                    var document: SyncDocument?
                    NSFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { readingURL in
                        guard !token.cancelled, let file = try? FileHandle(forReadingFrom: readingURL) else { return }
                        defer { try? file.close() }
                        if let data = try? file.read(upToCount: 1_048_577), data.count <= 1_048_576, let decoded = try? JSONDecoder().decode(SyncDocument.self, from: data), decoded.schema == 1, decoded.entries.count <= 4096 { document = decoded }
                    }
                    if let coordinationError { throw coordinationError }
                    if let document {
                        totalEntries += document.entries.count
                        guard totalEntries <= 8192 else { throw CocoaError(.fileReadTooLarge) }
                        documents.append(document)
                    }
                }
                DispatchQueue.main.async { self?.received(documents, folder: connection, token: token) }
            } catch {
                DispatchQueue.main.async {
                    guard let self, self.connectionToken === token, !token.cancelled else { return }
                    self.busy = false
                    if self.folder == connection { self.status = "unavailable"; self.onStatus?() }
                }
            }
        }
    }
    private func received(_ documents: [SyncDocument], folder: URL, token: SyncConnectionToken) {
        guard connectionToken === token, !token.cancelled, self.folder == folder else { return }
        // Preserve edits made while the folder was being read.
        if initialized { captureLocal() }
        let initialWords = Set((defaults.stringArray(forKey: "excludedWords") ?? []).map(ExclusionRules.normalize))
        let localChanges = snapshot().filter { connectionBaseline[$0.key] != $0.value }
        for document in documents { entries = SyncRules.merge(entries, document.entries) }
        if !initialized {
            // A choice made while the first folder read was in progress wins over imported defaults.
            func keepLocal(_ key: String, _ value: SyncValue) {
                entries[key] = SyncEntry(value: value, modified: max(Date().timeIntervalSince1970, (entries[key]?.modified ?? 0) + 0.000001), writer: device)
            }
            for (key, value) in localChanges { keepLocal(key, value) }
            for word in connectionWords.symmetricDifference(initialWords) { keepLocal(SyncRules.wordKey(word), .boolean(initialWords.contains(word))) }
            for word in initialWords where entries[SyncRules.wordKey(word)] == nil {
                entries[SyncRules.wordKey(word)] = SyncEntry(value: .boolean(true), modified: Date().timeIntervalSince1970, writer: device)
            }
        }
        let changed = apply()
        initialized = true
        captureLocal()
        cache()
        if changed { onApply?() }
        guard let data = try? JSONEncoder().encode(SyncDocument(device: device, entries: entries)), data.count <= 1_048_576 else { busy = false; status = "tooLarge"; onStatus?(); return }
        let destination = folder.appendingPathComponent("KiYo-settings-\(device).json")
        queue.async { [weak self] in
            guard !token.cancelled else { return }
            var coordinatorError: NSError?
            var writeError: Error?
            NSFileCoordinator().coordinate(writingItemAt: destination, options: .forReplacing, error: &coordinatorError) { url in
                do {
                    guard !token.cancelled else { return }
                    let existing = try? FileHandle(forReadingFrom: url)
                    let oldData = try? existing?.read(upToCount: 1_048_577)
                    try? existing?.close()
                    if oldData != data { try data.write(to: url, options: .atomic) }
                } catch { writeError = error }
            }
            DispatchQueue.main.async {
                guard let self, self.connectionToken === token, !token.cancelled else { return }
                self.busy = false
                guard self.folder == folder else { return }
                let newStatus = coordinatorError == nil && writeError == nil ? "ready" : "unavailable"
                if self.status != newStatus { self.status = newStatus; self.onStatus?() }
            }
        }
    }
}
