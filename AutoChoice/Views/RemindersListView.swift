// AutoChoice — RemindersListView.swift
// Premium-only Reminders list. Shows scheduled daily spin reminders;
// non-premium users see a paywall CTA.

import SwiftUI

struct RemindersListView: View {
    @Environment(WheelStore.self) private var store
    @Environment(IAPManager.self) private var iap

    @State private var showPaywall = false
    @State private var editing: WheelReminder?

    var body: some View {
        Group {
            if iap.isPremium {
                premiumView
            } else {
                lockedView
            }
        }
        .navigationTitle(LocalizedStringKey("Reminders"))
        .toolbar {
            if iap.isPremium {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let listID = store.activeList?.id ?? store.lists.first?.id ?? UUID()
                        editing = WheelReminder(listID: listID, hour: 12, minute: 0)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text(LocalizedStringKey("Add reminder")))
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
        .sheet(item: $editing) { reminder in
            ReminderEditView(
                reminder: reminder,
                onSave: { updated in
                    @Bindable var s = store
                    if let idx = store.reminders.firstIndex(where: { $0.id == updated.id }) {
                        store.reminders[idx] = updated
                    } else {
                        store.reminders.append(updated)
                    }
                },
                onDelete: { id in
                    store.reminders.removeAll { $0.id == id }
                }
            )
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .task {
            _ = await NotificationService.requestPermissionIfNeeded()
        }
    }

    // MARK: - Premium view

    @ViewBuilder
    private var premiumView: some View {
        if store.reminders.isEmpty {
            ContentUnavailableView(
                LocalizedStringKey("No reminders yet"),
                systemImage: "bell.slash",
                description: Text(LocalizedStringKey("Tap + to schedule a daily spin reminder."))
            )
        } else {
            List {
                ForEach(store.reminders) { reminder in
                    Button {
                        editing = reminder
                    } label: {
                        reminderRow(reminder)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            store.reminders.removeAll { $0.id == reminder.id }
                        } label: {
                            Label(LocalizedStringKey("Delete"), systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Locked view (non-premium)

    private var lockedView: some View {
        ContentUnavailableView {
            Label(LocalizedStringKey("Premium feature"), systemImage: "lock.fill")
        } description: {
            Text(LocalizedStringKey("Schedule daily reminders to spin your wheels. Available with AutoChoice Premium."))
        } actions: {
            Button(LocalizedStringKey("Unlock Premium")) {
                showPaywall = true
            }
            .buttonStyle(.borderedProminent)
            .frame(minWidth: 44, minHeight: 44)
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func reminderRow(_ r: WheelReminder) -> some View {
        let listName = store.lists.first(where: { $0.id == r.listID })?.name
            ?? NSLocalizedString("Unknown list", comment: "Reminder row — list no longer exists")
        HStack(spacing: 12) {
            Toggle(
                "",
                isOn: Binding(
                    get: { r.enabled },
                    set: { newValue in
                        if let idx = store.reminders.firstIndex(where: { $0.id == r.id }) {
                            store.reminders[idx].enabled = newValue
                        }
                    }
                )
            )
            .labelsHidden()
            .frame(minWidth: 44, minHeight: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(timeString(r.time))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(r.enabled ? .primary : .secondary)
                Text(listName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !r.label.isEmpty {
                    Text(r.label)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text(r.isEveryDay
                 ? NSLocalizedString("Daily", comment: "Reminder repeat — every day")
                 : weekdaysString(r.weekdays))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(
            format: "%@, %@, %@",
            timeString(r.time),
            listName,
            r.isEveryDay
                ? NSLocalizedString("Daily", comment: "")
                : weekdaysString(r.weekdays)
        )))
    }

    // MARK: - Helpers

    private func timeString(_ comps: DateComponents) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        guard let date = Calendar.current.date(from: comps) else { return "--:--" }
        return formatter.string(from: date)
    }

    private func weekdaysString(_ days: Set<Int>) -> String {
        let names = Calendar.current.shortWeekdaySymbols  // index 0 = Sunday
        return days.sorted().compactMap { day in
            guard (1...7).contains(day) else { return nil }
            return names[day - 1]
        }.joined(separator: " ")
    }
}
