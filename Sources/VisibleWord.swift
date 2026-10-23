import ApplicationServices
import Foundation

// Read only the characters already observed, plus one preceding boundary character.
// Do not read entire documents or recover text typed before monitoring began.
enum VisibleWord {
    static func beforeCaret(pid: pid_t, expectedUTF16Count: Int) -> String? {
        guard (1...64).contains(expectedUTF16Count) else { return nil }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.02)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused) == .success, let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.02)
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success, let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return nil }
        var caret = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &caret), caret.length == 0, caret.location >= expectedUTF16Count else { return nil }
        let extra = caret.location > expectedUTF16Count ? 1 : 0
        var range = CFRange(location: caret.location - expectedUTF16Count - extra, length: expectedUTF16Count + extra)
        guard let parameter = AXValueCreate(.cfRange, &range) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXStringForRangeParameterizedAttribute as CFString, parameter, &value) == .success, let text = value as? String else { return nil }
        return validated(text, expectedUTF16Count: expectedUTF16Count, hasBoundary: extra == 1)
    }
    static func validated(_ text: String, expectedUTF16Count: Int, hasBoundary: Bool) -> String? {
        guard (1...64).contains(expectedUTF16Count) else { return nil }
        var word = text
        if hasBoundary {
            guard let first = word.first, first.isWhitespace else { return nil }
            word.removeFirst()
        }
        guard word.utf16.count == expectedUTF16Count, !word.contains(where: { $0.isWhitespace }), !word.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
        return word
    }
}
