import AppKit
import ApplicationServices

// Exercises the production callback and replacement path. Events never enter macOS.
func runTypingStressTests() {
    let app = App()
    app.enabled = true
    app.testSensitivity = 1
    app.testShortWords = true
    app.testSpellingEnabled = false
    app.testConversionShortcutID = "ctrlOptR"
    var document = ""
    var injectedEvents = 0
    var boundaryKeys: [Int64] = []
    app.testOutput = { event in
        injectedEvents += 1
        guard event.type == .keyDown else { return }
        if [36, 48].contains(event.getIntegerValueField(.keyboardEventKeycode)) { boundaryKeys.append(event.getIntegerValueField(.keyboardEventKeycode)) }
        if event.getIntegerValueField(.keyboardEventKeycode) == 51 {
            if !document.isEmpty { document.removeLast() }
        } else {
            var units = [UniChar](repeating: 0, count: 256)
            var length = 0
            event.keyboardGetUnicodeString(maxStringLength: units.count, actualStringLength: &length, unicodeString: &units)
            document += String(utf16CodeUnits: units, count: length)
        }
        // Injected replacement events must never trigger another correction.
        assert(!app.handle(type: event.type, event: event, proxy: nil))
    }
    func type(_ text: String) {
        for character in text {
            let key: CGKeyCode = character == " " ? 49 : character == "\n" || character == "\r" ? 36 : character == "\t" ? 48 : character == "\u{8}" ? 51 : 0
            let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true)!
            event.flags = []
            let units = Array(String(character).utf16)
            event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            if !app.handle(type: .keyDown, event: event, proxy: nil) {
                if key == 51 { if !document.isEmpty { document.removeLast() } }
                else { document.append(character) }
            }
            let release = event.copy()!
            release.type = .keyUp
            assert(!app.handle(type: .keyUp, event: release, proxy: nil))
        }
    }
    assert(ExclusionRules.wordsFromSelection("  Python,\nPostgres! CRM ") == ["python", "postgres", "crm"])
    assert(ExclusionRules.wordsFromSelection("!!!") == [])
    assert(ExclusionRules.wordsFromSelection(String(repeating: "a", count: 513)) == [])
    let cases = [
        ("Лшнщ ЛшНщ KiYo kiyo KIYO kIyO ", "KiYo KiYo KiYo KiYo KiYo KiYo "),
        ("рш рщц фку нщг ", "hi how are you "),
        ("ghbdtn rfr ltkf ", "привет как дела "),
        ("hello how are you ", "hello how are you "),
        ("привет как дела ", "привет как дела "),
        ("ghbdtn  rfr   ltkf ", "привет  как   дела "),
        ("Ghbdtn Rfr Ltkf ", "Привет Как Дела "),
        ("hello, hello! 123\n", "hello, hello! 123\n"),
        ("Ghbdtn, rfr ltkf? ", "Привет, как дела? "),
        ("ghbdtn\n rfr\tltkf\n", "привет\n как\tдела\n"),
        ("ghbdtx\u{8}n rfr ltkf ", "привет как дела "),
        (LayoutConverter.convert("keyboard application computer "), "keyboard application computer "),
        (LayoutConverter.convert("клавиатура приложение компьютер "), "клавиатура приложение компьютер ")
    ]
    let began = DispatchTime.now().uptimeNanoseconds
    var checkedCharacters = 0
    for iteration in 0..<500 {
        for (input, expected) in cases {
            document = ""
            app.buffer = ""
            type(input)
            assert(document == expected, "Iteration \(iteration): expected \(expected.debugDescription), got \(document.debugDescription)")
            checkedCharacters += input.count
        }
    }
    // Polling must not erase letters typed while our previous source switch settles.
    let layoutState = App()
    layoutState.currentRussian = true
    layoutState.pendingLayoutChange = (false, Date().addingTimeInterval(2))
    layoutState.buffer = "gh"
    layoutState.observeKeyboardLayout(true)
    assert(layoutState.buffer == "gh")
    layoutState.observeKeyboardLayout(false)
    assert(layoutState.buffer == "gh", "An automatic source acknowledgement erased the next word")
    assert(layoutState.pendingLayoutChange == nil)
    layoutState.observeKeyboardLayout(true)
    assert(layoutState.buffer.isEmpty, "An external source change must invalidate partial input")
    // Keep one buffer/state across alternating conversion directions.
    document = ""
    app.buffer = ""
    app.correctionRejections = CorrectionRejections()
    for _ in 0..<20 { type("ghbdtn рш ghbdtn ") }
    assert(document == String(repeating: "привет hi привет ", count: 20), "Alternating directions stopped correcting")
    func expect(_ input: String, _ expected: String) {
        document = ""; app.buffer = ""
        type(input)
        assert(document == expected, "Protected input changed: \(input.debugDescription)")
    }
    for token in ["ghbdtn@rfr.ltkf ", "test+ghbdtn@example.com ", "123ghbdtn ", "https://ghbdtn/rfr ", "www.ghbdtn.com "] {
        expect(token, token)
    }
    let longToken = String(repeating: "a", count: 65) + "ghbdtn"
    expect(longToken + " ghbdtn ", longToken + " привет ")
    expect(longToken + "\u{8} ", String(longToken.dropLast()) + " ")
    expect("РУ ру Ру ", "РУ ру Ру ")
    expect("СКЬ УкЗ ФЗШ ЫЙД ", "CRM ErP API SQL ")
    app.testExcludedWords = ["привет", "how"]
    expect("ghbdtn рщц Ghbdtn, ", "ghbdtn рщц Ghbdtn, ")
    app.testExcludedWords = []
    app.testProtectedField = true
    let lettersBefore = app.observedLetters
    expect("ghbdtn рщц ", "ghbdtn рщц ")
    assert(app.observedLetters == lettersBefore, "Protected field must not enter the word buffer")
    app.testProtectedField = false
    expect("ghbdtn ", "привет ")
    app.testSpellingEnabled = true
    let layoutBeforeSpelling = app.testRussian
    expect("helllo ", "hello ")
    expect("Helllo, ", "Hello, ")
    expect("превет ", "привет ")
    expect("праивльно поставвить ", "правильно поставить ")
    expect("нунжно Нунжно, ", "нужно Нужно, ")
    expect("чтобыпотом Чтобыпотом ", "чтобы потом Чтобы потом ")
    expect("какбудто ", "как будто ")
    expect("которыепишутсявместе ", "которые пишутся вместе ")
    expect("чтобы потом ", "чтобы потом ")
    assert(app.testRussian == layoutBeforeSpelling, "Spelling must not switch keyboard layouts")
    app.testExcludedWords = ["helllo"]
    expect("helllo ", "helllo ")
    app.testExcludedWords = []
    app.testProtectedField = true
    expect("helllo ", "helllo ")
    app.testProtectedField = false
    app.testSpellingEnabled = false
    expect("helllo ", "helllo ")
    boundaryKeys = []
    expect("ghbdtn\t", "привет\t")
    expect("ghbdtn\n", "привет\n")
    assert(boundaryKeys == [48, 36], "Tab and Return must preserve their original keycodes")
    app.correctionRejections = CorrectionRejections()
    expect("ghbdtn " + String(repeating: "\u{8}", count: 7) + "ghbdtn ", "ghbdtn ")
    assert(!app.correctionRejections.shouldPreserve("ghbdtn"), "Retry preservation must be consumed once")
    assert(!app.testRussian, "Erasing the correction restores the original input layout")
    app.correctionRejections = CorrectionRejections()
    // Erasing one correction must not disable that word for the rest of the session.
    app.correctionRejections = CorrectionRejections()
    expect("ghbdtn " + String(repeating: "\u{8}", count: 7) + "рш ghbdtn ", "hi привет ")
    app.correctionRejections = CorrectionRejections()
    expect("ghbdtn " + String(repeating: "\u{8}", count: 7) + "ghbdtn ghbdtn ", "ghbdtn привет ")
    var retry = CorrectionRejections()
    let time = Date()
    retry.record(word: "sample", outputCount: 3, pid: 1, now: time)
    retry.backspace(pid: 1, now: time)
    assert(!retry.shouldPreserve("sample"))
    retry.cancel()
    retry.backspace(pid: 1, now: time)
    assert(!retry.shouldPreserve("sample"))
    retry.record(word: "sample", outputCount: 1, pid: 1, now: time)
    retry.backspace(pid: 2, now: time)
    assert(!retry.shouldPreserve("sample"))
    retry.record(word: "sample", outputCount: 1, pid: 1, now: time)
    retry.backspace(pid: 1, now: time.addingTimeInterval(16))
    assert(!retry.shouldPreserve("sample"))
    assert(SelectionConversion.converted("ghbdtn, vbh!\nруддщ 😀") == "привет, мир!\nhello 😀")
    assert(SelectionConversion.converted("Привет\nHello") == "Ghbdtn\nРуддщ")
    assert(SelectionConversion.converted("😀\n") == nil)
    assert(SelectionConversion.converted(String(repeating: "a", count: SelectionConversion.limit + 1)) == nil)
    let convertKey = CGEvent(keyboardEventSource: nil, virtualKey: 15, keyDown: true)!
    convertKey.flags = [.maskControl, .maskAlternate]
    app.enabled = false
    app.testSelection = "ghbdtn\nруддщ"
    assert(app.handle(type: .keyDown, event: convertKey, proxy: nil))
    assert(app.testConvertedSelection == "привет\nhello", "Explicit selection conversion must also work while paused")
    app.testConvertedSelection = nil
    app.testProtectedField = true
    assert(!app.handle(type: .keyDown, event: convertKey, proxy: nil))
    assert(app.testConvertedSelection == nil)
    app.testProtectedField = false
    app.testConversionShortcutID = "off"
    assert(!app.handle(type: .keyDown, event: convertKey, proxy: nil))
    app.testConversionShortcutID = "ctrlOptR"
    retry.record(word: "sample", outputCount: 1, pid: 1, now: time)
    retry.backspace(pid: 1, now: time)
    assert(!retry.consumePreservation("sample", now: time.addingTimeInterval(16)))
    assert(!retry.shouldPreserve("sample", now: time.addingTimeInterval(17)))
    app.testSelection = "ExampleTerm, другойтермин"
    app.testExcludedWords = []
    app.enabled = false
    let shortcut = CGEvent(keyboardEventSource: nil, virtualKey: 40, keyDown: true)!
    shortcut.flags = [.maskControl, .maskAlternate]
    // Invoke matching independently of the user's configured shortcut.
    assert(ExclusionShortcut.matches("ctrlOptK", key: 40, flags: shortcut.flags))
    app.testShortcutID = "ctrlOptK"
    assert(app.handle(type: .keyDown, event: shortcut, proxy: nil))
    assert(app.excludedWords == ["exampleterm", "другойтермин"])
    app.testSelection = ""
    app.addSelectionWithShortcut(pid: 0)
    assert(app.excludedWords.count == 2)
    app.testProtectedField = true
    app.testSelection = "protectedword"
    assert(!app.handle(type: .keyDown, event: shortcut, proxy: nil))
    assert(!app.excludedWords.contains("protectedword"))
    app.testProtectedField = false
    app.testShortcutID = "off"
    assert(!app.handle(type: .keyDown, event: shortcut, proxy: nil))
    assert(!app.excludedWords.contains("protectedword"))
    let elapsed = Double(DispatchTime.now().uptimeNanoseconds - began) / 1_000_000
    assert(app.tapTimeouts == 0)
    print("Stress checks passed: \(cases.count * 500) phrases, \(checkedCharacters) input characters, \(injectedEvents) replacement events; \(Int(elapsed)) ms total, max callback \(String(format: "%.2f", app.callbackMaximumMS)) ms. No system events posted.")
}
