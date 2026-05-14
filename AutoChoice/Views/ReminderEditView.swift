// AutoChoice — ReminderEditView.swift
// Sheet editor for a single WheelReminder.
// Presents time picker, weekday selector, list picker, and label field.

import SwiftUI

struct ReminderEditView: View {
    @Environment(WheelStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: WheelReminder
    let onSave: (WheelReminder) -> Void
    let onDelete: (UUID) -> Void

    init(
        reminder: WheelReminder,
        onSave: @escaping (WheelReminder) -> Void,
        onDelete: @escaping (UUID) -> Void
    ) {
        self._draft = State(initialValue: reminder)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                listSection
                timeSection
                repeatSection
                labelSection
                deleteSection
            }
            .navigationTitle(LocalizedStringKey("Edit reminder"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Save")) {
                        onSave(draft)
                        dismiss()
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(store.lists.isEmpty)
                }
            }
        }
    }

    // MARK: - Sections

    private var listSection: some View {
        Section(LocalizedStringKey("List")) {
            Picker(LocalizedStringKey("List"), selection: $draft.listID) {
                ForEach(store.lists) { list in
                    Text(list.name).tag(list.id)
                }
            }
        }
    }

    private var timeSection: some View {
        Section(LocalizedStringKey("Time")) {
            DatePicker(
                LocalizedStringKey("Time"),
                selection: Binding(
                    get: {
                        Calendar.current.date(from: draft.time) ?? Date()
                    },
                    set: { newDate in
                        draft.time = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                    }
                ),
                displayedComponents: .hourAndMinute
            )
        }
    }

    private var repeatSection: some View {
        Section(LocalizedStringKey("Repeat")) {
            Toggle(LocalizedStringKey("Every day"), isOn: Binding(
                get: { draft.isEveryDay },
                set: { isEveryDay in
                    // Toggle between "every day" (empty set) and Mon–Fri default.
                    draft.weekdays = isEveryDay ? [] : Set([2, 3, 4, 5, 6])
                }
            ))
            .frame(minHeight: 44)

            if !draft.isEveryDay {
                weekdayPicker
            }
        }
    }

    private var labelSection: some View {
        Section(LocalizedStringKey("Label (optional)")) {
            TextField(LocalizedStringKey("e.g., Lunch decision"), text: $draft.label)
                .frame(minHeight: 44)
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                onDelete(draft.id)
                dismiss()
            } label: {
                Label(LocalizedStringKey("Delete reminder"), systemImage: "trash")
            }
            .frame(minHeight: 44)
        }
    }

    // MARK: - Weekday Picker

    @ViewBuilder
    private var weekdayPicker: some View {
        HStack(spacing: 4) {
            ForEach(1...7, id: \.self) { day in
                let isSelected = draft.weekdays.contains(day)
                Button {
                    if isSelected {
                        draft.weekdays.remove(day)
                    } else {
                        draft.weekdays.insert(day)
                    }
                } label: {
                    Text(Calendar.current.shortWeekdaySymbols[day - 1])
                        .font(.caption2)
                        .lineLimit(1)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            isSelected ? Color.accentColor : Color(.systemFill),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(Calendar.current.weekdaySymbols[day - 1]))
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.vertical, 4)
    }
}
