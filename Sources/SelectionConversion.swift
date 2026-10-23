import AppKit
import ApplicationServices
import Carbon

// Explicit conversion preserves line breaks, punctuation and text outside the keyboard map.
enum SelectionConversion {
    static let limit = 131_072
    static func converted(_ text: String) -> String? {
        guard !text.isEmpty, text.utf16.count <= limit else { return nil }
        var result = ""
        var token = ""
        func appendToken() {
            if let lastLetter = token.lastIndex(where: { !".,!?;:".contains($0) }) {
                let end = token.index(after: lastLetter)
                result += LayoutConverter.convert(String(token[..<end])) + token[end...]
            } else { result += token }
            token = ""
        }
        for character in text {
            if character.isWhitespace { appendToken(); result.append(character) }
            else { token.append(character) }
        }
        appendToken()
        return result == text ? nil : result
    }
}

private struct SelectionClipboard {
    let items: [[(NSPasteboard.PasteboardType, Data)]]
    init?(_ board: NSPasteboard) {
        var saved: [[(NSPasteboard.PasteboardType, Data)]] = []
        var bytes = 0
        for item in board.pasteboardItems ?? [] {
            var values: [(NSPasteboard.PasteboardType, Data)] = []
            for type in item.types {
                guard let data = item.data(forType: type) else { return nil }
                bytes += data.count
                guard bytes <= 8_388_608 else { return nil }
                values.append((type, data))
            }
            saved.append(values)
        }
        items = saved
    }
    func restore(_ board: NSPasteboard, ifUnchanged count: Int) {
        // Do not overwrite a clipboard update made by the user or another app.
        guard board.changeCount == count else { return }
        board.clearContents()
        let restored = items.map { values -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in values { item.setData(data, forType: type) }
            return item
        }
        if !restored.isEmpty { board.writeObjects(restored) }
    }
}

extension App {
    func convertSelectionWithShortcut(pid: pid_t) {
        if testOutput != nil {
            guard !testProtectedField else { return }
            testConvertedSelection = SelectionConversion.converted(testSelection ?? "")
            return
        }
        guard !shortcutBusy, !IsSecureEventInputEnabled(), !protectedField(pid: pid), NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.1)
        func focused() -> AXUIElement? {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &value) == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
            return (value as! AXUIElement)
        }
        guard let element = focused() else { selectionFeedback(false, conversion: true); return }
        AXUIElementSetMessagingTimeout(element, 0.1)
        func attribute(_ name: String) -> CFTypeRef? {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
            return value
        }
        let selected = attribute(kAXSelectedTextAttribute) as? String
        let range = attribute(kAXSelectedTextRangeAttribute)
        let epoch = selectionEpoch
        func unchanged() -> Bool {
            guard selectionEpoch == epoch, NSWorkspace.shared.frontmostApplication?.processIdentifier == pid, !IsSecureEventInputEnabled(), !protectedField(pid: pid), let current = focused(), CFEqual(element, current) else { return false }
            if let range {
                guard let currentRange = attribute(kAXSelectedTextRangeAttribute), CFEqual(range, currentRange) else { return false }
            }
            if let selected, !selected.isEmpty, (attribute(kAXSelectedTextAttribute) as? String) != selected { return false }
            return true
        }
        var selectedSettable = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &selectedSettable)
        if let selected, !selected.isEmpty, let converted = SelectionConversion.converted(selected), selectedSettable.boolValue {
            guard unchanged() else { return }
            if AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, converted as CFString) == .success {
                buffer = ""
                selectLayout(russian: LayoutConverter.russian(converted))
                selectionFeedback(true, conversion: true)
                return
            }
            // A failed setter can still change focus or selection; recheck before fallback.
            guard unchanged() else { return }
        }
        // Paste is allowed only in an editable control, never in selected static page text.
        let role = attribute(kAXRoleAttribute) as? String ?? ""
        guard [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role), (attribute(kAXEnabledAttribute) as? Bool) != false,
              let snapshot = SelectionClipboard(NSPasteboard.general) else { selectionFeedback(false, conversion: true); return }
        func chord(_ key: CGKeyCode) -> [CGEvent]? {
            guard let down = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true), let up = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false) else { return nil }
            for event in [down, up] { event.flags = .maskCommand; event.setIntegerValueField(.eventSourceUserData, value: injectedTag) }
            return [down, up]
        }
        guard let copy = chord(8), let paste = chord(9), unchanged() else { return }
        let board = NSPasteboard.general
        let baseline = board.changeCount
        shortcutBusy = true
        for event in copy { event.postToPid(pid) }
        func finish(_ attempts: Int) {
            let count = board.changeCount
            guard unchanged() else {
                if count != baseline { snapshot.restore(board, ifUnchanged: count) }
                shortcutBusy = false
                return
            }
            if count == baseline && attempts > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { finish(attempts - 1) }
                return
            }
            guard count != baseline, let copied = board.string(forType: .string), let converted = SelectionConversion.converted(copied), (selected?.isEmpty != false || selected == copied) else {
                if count != baseline { snapshot.restore(board, ifUnchanged: count) }
                shortcutBusy = false
                selectionFeedback(false, conversion: true)
                return
            }
            guard unchanged(), board.changeCount == count else { shortcutBusy = false; return }
            board.clearContents()
            guard board.setString(converted, forType: .string) else {
                snapshot.restore(board, ifUnchanged: board.changeCount)
                shortcutBusy = false
                return
            }
            let pastedCount = board.changeCount
            for event in paste { event.postToPid(pid) }
            buffer = ""
            selectLayout(russian: LayoutConverter.russian(converted))
            // Apps can read the pasteboard asynchronously; restoration is best effort.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                snapshot.restore(board, ifUnchanged: pastedCount)
                self.shortcutBusy = false
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { finish(11) }
    }
}
