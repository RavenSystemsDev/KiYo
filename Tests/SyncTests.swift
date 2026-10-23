import Foundation

func runSyncTests() {
    let a = SyncEntry(value: .string("ru"), modified: 100, writer: "a")
    let b = SyncEntry(value: .string("en"), modified: 101, writer: "b")
    assert(SyncRules.merge(["language": a], ["language": b])["language"] == b)
    assert(SyncRules.merge(["language": b], ["language": a])["language"] == b)
    let tie = SyncEntry(value: .string("system"), modified: 101, writer: "c")
    assert(SyncRules.merge(["language": b], ["language": tie]) == SyncRules.merge(["language": tie], ["language": b]))
    let w1 = SyncRules.wordKey("postgres")
    let w2 = SyncRules.wordKey("свойтермин")
    let add = SyncEntry(value: .boolean(true), modified: 100, writer: "a")
    let remove = SyncEntry(value: .boolean(false), modified: 102, writer: "b")
    let combined = SyncRules.merge([w1: add], [w2: add])
    assert(combined.count == 2)
    assert(SyncRules.merge(combined, [w1: remove])[w1] == remove)
    assert(SyncRules.merge([w1: remove], [w1: add])[w1] == remove)
    assert(SyncRules.word(w2) == "свойтермин")
    assert(SyncRules.merge([:], ["welcomeCompleted": add, "loginItemConfigured": add, "accessibility": add]).isEmpty)
    assert(SyncRules.merge([:], ["sensitivity": SyncEntry(value: .integer(99), modified: 1, writer: "a")]).isEmpty)
    assert(SyncRules.merge([:], ["language": SyncEntry(value: .string("invalid"), modified: 1, writer: "a")]).isEmpty)
    assert(!SyncRules.valid("language", SyncEntry(value: .string("en"), modified: Date().timeIntervalSince1970 + 3600, writer: "remote")))
    assert(SyncRules.word(SyncRules.wordKey("bad\u{0}word")) == nil)
    let customShortcut = ExclusionShortcut.encode(key: 35, flags: [.maskControl, .maskAlternate, .maskShift])!
    assert(SyncRules.valid("exclusionShortcut", SyncEntry(value: .string(customShortcut), modified: 100, writer: "a")))
    assert(!SyncRules.valid("exclusionShortcut", SyncEntry(value: .string("custom:999:0"), modified: 100, writer: "a")))
    let document = SyncDocument(device: "a", entries: combined)
    let data = try! JSONEncoder().encode(document)
    assert(try! JSONDecoder().decode(SyncDocument.self, from: data).entries == combined)
    // Two actual files model independent offline writers, without using the user's iCloud.
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("kiyo-sync-test-" + UUID().uuidString)
    try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    try! data.write(to: folder.appendingPathComponent("KiYo-settings-a.json"), options: .atomic)
    try! JSONEncoder().encode(SyncDocument(device: "b", entries: [w1: remove, "language": b])).write(to: folder.appendingPathComponent("KiYo-settings-b.json"), options: .atomic)
    var merged: [String: SyncEntry] = [:]
    for file in try! FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
        let read = try! JSONDecoder().decode(SyncDocument.self, from: Data(contentsOf: file))
        merged = SyncRules.merge(merged, read.entries)
    }
    assert(merged[w1] == remove && merged[w2] == add && merged["language"] == b)
    // Exercise the actual sync service with two isolated preference stores.
    let suiteA = "io.ravensystems.kiyo.test." + UUID().uuidString
    let suiteB = "io.ravensystems.kiyo.test." + UUID().uuidString
    let defaultsA = UserDefaults(suiteName: suiteA)!
    let defaultsB = UserDefaults(suiteName: suiteB)!
    defer { defaultsA.removePersistentDomain(forName: suiteA); defaultsB.removePersistentDomain(forName: suiteB) }
    let serviceFolder = folder.appendingPathComponent("service")
    try! FileManager.default.createDirectory(at: serviceFolder, withIntermediateDirectories: true)
    let serviceA = PreferencesSync(defaults: defaultsA)
    let serviceB = PreferencesSync(defaults: defaultsB)
    func settle(_ service: PreferencesSync) {
        let limit = Date().addingTimeInterval(5)
        while service.isWorking && Date() < limit { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        assert(!service.isWorking && service.status == "ready", "Sync service failed: \(service.status)")
    }
    defaultsA.set(customShortcut, forKey: "exclusionShortcut")
    defaultsA.set("ru", forKey: "language")
    defaultsA.set(["postgres"], forKey: "excludedWords")
    defaultsA.set(true, forKey: "loginItemConfigured")
    serviceA.connect(serviceFolder); settle(serviceA)
    serviceB.connect(serviceFolder); settle(serviceB)
    assert(defaultsB.string(forKey: "language") == "ru")
    assert(defaultsB.string(forKey: "exclusionShortcut") == customShortcut)
    assert(defaultsB.stringArray(forKey: "excludedWords") == ["postgres"])
    assert(defaultsB.object(forKey: "loginItemConfigured") == nil)
    defaultsA.set(["postgres", "alpha"], forKey: "excludedWords")
    defaultsB.set(["postgres", "beta"], forKey: "excludedWords")
    serviceA.refresh(); settle(serviceA)
    serviceB.refresh(); settle(serviceB)
    serviceA.refresh(); settle(serviceA)
    assert(Set(defaultsA.stringArray(forKey: "excludedWords")!) == ["postgres", "alpha", "beta"])
    defaultsA.set(["alpha", "beta"], forKey: "excludedWords")
    serviceA.refresh(); settle(serviceA)
    serviceB.refresh(); settle(serviceB)
    assert(Set(defaultsB.stringArray(forKey: "excludedWords")!) == ["alpha", "beta"])
    defaultsB.set(2, forKey: "sensitivity")
    defaultsB.set(false, forKey: "correctionEnabled")
    serviceB.refresh(); settle(serviceB)
    serviceA.refresh(); settle(serviceA)
    assert(defaultsA.integer(forKey: "sensitivity") == 2)
    assert(!defaultsA.bool(forKey: "correctionEnabled"))
    serviceA.disconnect()
    defaultsA.set("en", forKey: "language")
    serviceA.connect(serviceFolder); settle(serviceA)
    serviceB.refresh(); settle(serviceB)
    assert(defaultsB.string(forKey: "language") == "en", "Offline edits must survive reconnect")
    let suiteC = "io.ravensystems.kiyo.test." + UUID().uuidString
    let defaultsC = UserDefaults(suiteName: suiteC)!
    defer { defaultsC.removePersistentDomain(forName: suiteC) }
    let serviceC = PreferencesSync(defaults: defaultsC)
    serviceC.connect(serviceFolder)
    defaultsC.set("menubar", forKey: "presentation")
    settle(serviceC)
    assert(defaultsC.string(forKey: "presentation") == "menubar", "First sync must not overwrite a just-made choice")
    serviceA.refresh(); settle(serviceA)
    assert(defaultsA.string(forKey: "presentation") == "menubar")
    // A disconnected or superseded initial read cannot apply stale data or publish a new file.
    let raceSuite = "io.ravensystems.kiyo.test." + UUID().uuidString
    let raceDefaults = UserDefaults(suiteName: raceSuite)!
    defer { raceDefaults.removePersistentDomain(forName: raceSuite) }
    let raceService = PreferencesSync(defaults: raceDefaults)
    let emptyFolder = folder.appendingPathComponent("empty")
    try! FileManager.default.createDirectory(at: emptyFolder, withIntermediateDirectories: true)
    raceService.connect(serviceFolder)
    raceService.disconnect()
    raceDefaults.set("en", forKey: "language")
    raceService.connect(emptyFolder)
    settle(raceService)
    assert(raceDefaults.string(forKey: "language") == "en")
    raceService.disconnect()
    serviceC.disconnect()
    serviceA.disconnect(); serviceB.disconnect()
    print("Sync checks passed: conflicts, per-word additions/deletions, validation, JSON, two offline device files and two actual sync clients. No iCloud files accessed.")
}
