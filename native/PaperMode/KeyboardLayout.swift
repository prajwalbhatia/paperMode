import Carbon

func currentKeyboardSourceID() -> String? {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let property = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
    return Unmanaged<CFString>.fromOpaque(property).takeUnretainedValue() as String
}

/// Translate the physical shortcut key without modifiers. Do not fall back to
/// another layout for IMEs: only accept mappings we can verify for this source.
func currentUnlockKeyLabel() -> String? {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
    let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue()
    guard let bytes = CFDataGetBytePtr(data) else { return nil }
    let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
    var deadKeyState: UInt32 = 0
    var length = 0
    var characters = [UniChar](repeating: 0, count: 8)
    let status = UCKeyTranslate(layout, 37, UInt16(kUCKeyActionDisplay), 0,
        UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask),
        &deadKeyState, characters.count, &length, &characters)
    guard status == noErr, length > 0 else { return nil }
    return String(utf16CodeUnits: characters, count: length)
}
