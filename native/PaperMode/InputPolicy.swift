import Foundation

/// NX_SYSDEFINED classifications from IOKit/hidsystem/IOLLEvent.h and ev_keymap.h.
/// Subtypes and key identifiers are different namespaces.
enum InputPolicy {
    static func suppressSystemEvent(subtype: Int, data1: Int) -> Bool {
        switch subtype {
        case 7: // NX_SUBTYPE_AUX_MOUSE_BUTTONS: changed/current button masks
            return true
        case 10: // NX_SUBTYPE_EJECT_KEY
            return true
        case 16: // NX_SUBTYPE_MENU
            return true
        case 8: // NX_SUBTYPE_AUX_CONTROL_BUTTONS: key identifier in high word
            let key = (data1 >> 16) & 0xffff
            switch key {
            case 0...5, 7...23, 25: return true
            default: return false // Includes NX_POWER_KEY (6) and unknown keys.
            }
        default:
            // Preserve power, sleep/restart/shutdown, accessibility and unknown events.
            return false
        }
    }
}

enum UnlockLayoutPolicy {
    // Gate fixed physical keycode 37 by its verified, unmodified character.
    static func supports(_ keyLabel: String?) -> Bool {
        keyLabel == "l" || keyLabel == "L"
    }
}
