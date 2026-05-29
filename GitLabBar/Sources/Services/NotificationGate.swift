import Foundation

/// Decides whether a notification should actually be delivered, given the
/// quiet-hours schedule and the mute-until override stored in `AppSettings`.
enum NotificationGate {

    struct Inputs: Sendable {
        let now: Date
        let quietEnabled: Bool
        let quietStartMinutes: Int   // minutes since midnight, local time
        let quietEndMinutes: Int
        let muteUntil: Date?
    }

    static func shouldDeliver(_ inputs: Inputs) -> Bool {
        if let until = inputs.muteUntil, inputs.now < until {
            return false
        }
        guard inputs.quietEnabled else { return true }
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: inputs.now)
        let nowMin = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let s = inputs.quietStartMinutes
        let e = inputs.quietEndMinutes
        if s == e { return true } // disabled by equal bounds
        // Window may wrap across midnight (e.g. 22:00 → 06:00).
        if s < e {
            // not in [s, e)
            return !(nowMin >= s && nowMin < e)
        } else {
            // wraps midnight: quiet = [s, 24) ∪ [0, e)
            return !(nowMin >= s || nowMin < e)
        }
    }
}
