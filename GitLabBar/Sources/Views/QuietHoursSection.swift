import SwiftUI

/// Notifications-section block: quiet hours schedule + manual mute-now controls.
struct QuietHoursSection: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Section {
            Toggle("Enable quiet hours", isOn: $settings.quietHoursEnabled)
            HStack {
                stepper("Start", minutes: $settings.quietStartMin)
                stepper("End",   minutes: $settings.quietEndMin)
            }
            .disabled(!settings.quietHoursEnabled)
            Text("Notifications are suppressed while the current time is inside the window. Window may wrap midnight.")
                .font(.caption).foregroundStyle(.secondary)

            Divider()

            HStack {
                if let until = settings.muteUntil {
                    Text("Muted until \(until, style: .time)")
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("Unmute") { settings.unmute() }
                } else {
                    Text("Mute now for:").foregroundStyle(.secondary)
                    Button("15m") { settings.muteNow(for: 15 * 60) }
                    Button("1h")  { settings.muteNow(for: 60 * 60) }
                    Button("Until tomorrow") { settings.muteNow(for: secondsUntilTomorrow()) }
                    Spacer()
                }
            }
        } header: {
            Text("Quiet hours").font(.headline)
        }
    }

    private func stepper(_ label: String, minutes: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Stepper(value: minutes, in: 0...(24 * 60 - 1), step: 30) {
                Text(formatHM(minutes.wrappedValue)).monospacedDigit()
            }
        }
    }

    private func formatHM(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%02d:%02d", h, m)
    }

    private func secondsUntilTomorrow() -> TimeInterval {
        let cal = Calendar.current
        let tomorrow = cal.startOfDay(for: Date()).addingTimeInterval(24 * 3600)
        return tomorrow.timeIntervalSince(Date())
    }
}
