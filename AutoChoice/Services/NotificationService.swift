// AutoChoice — NotificationService.swift
// Manages local UNCalendarNotificationTrigger reminders for premium users.
// No server. All scheduling is on-device.

import Foundation
import UserNotifications

enum NotificationService {
    static let identifierPrefix = "autochoice.reminder."

    @MainActor
    static func requestPermissionIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    /// Clears all existing AutoChoice reminders, then schedules the enabled ones.
    /// Runs asynchronously; safe to call from a didSet observer via Task { ... }.
    @MainActor
    static func refreshReminders(_ reminders: [WheelReminder], lists: [ChoiceList]) async {
        let center = UNUserNotificationCenter.current()

        // Remove previously scheduled AutoChoice reminders.
        let pending = await center.pendingNotificationRequests()
        let oldIDs = pending
            .filter { $0.identifier.hasPrefix(identifierPrefix) }
            .map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: oldIDs)

        // Schedule active reminders only.
        for reminder in reminders where reminder.enabled {
            guard let list = lists.first(where: { $0.id == reminder.listID }) else { continue }

            let content = UNMutableNotificationContent()
            content.title = reminder.label.isEmpty
                ? NSLocalizedString("Time to spin!", comment: "Reminder notification title")
                : reminder.label
            content.body = String(
                format: NSLocalizedString("Spin \"%@\" for a quick decision.", comment: "Reminder notification body"),
                list.name
            )
            content.sound = .default
            content.userInfo = ["listID": reminder.listID.uuidString]

            if reminder.isEveryDay {
                // Single daily repeating trigger — fires at the same time every day.
                let trigger = UNCalendarNotificationTrigger(dateMatching: reminder.time, repeats: true)
                let id = identifierPrefix + reminder.id.uuidString
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                try? await center.add(request)
            } else {
                // One trigger per active weekday.
                for weekday in reminder.weekdays.sorted() {
                    var comps = reminder.time
                    comps.weekday = weekday
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                    let id = "\(identifierPrefix)\(reminder.id.uuidString).w\(weekday)"
                    let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                    try? await center.add(request)
                }
            }
        }
    }
}
