// AutoChoice — LastResultWidget.swift
// WidgetKit widget that displays the last spin result.
// Supports: systemSmall, systemMedium, accessoryCircular,
//           accessoryRectangular, accessoryInline (Lock Screen / StandBy).
// Data source: App Group "group.com.jiejuefuyou.autochoice" shared defaults.

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct LastResultEntry: TimelineEntry {
    let date: Date
    let listName: String
    let lastResult: String?
    let choiceCount: Int
}

// MARK: - Timeline Provider

struct LastResultProvider: TimelineProvider {
    private static let groupID = "group.com.jiejuefuyou.autochoice"

    func placeholder(in context: Context) -> LastResultEntry {
        LastResultEntry(date: Date(), listName: "What to eat?", lastResult: "Pizza", choiceCount: 6)
    }

    func getSnapshot(in context: Context, completion: @escaping (LastResultEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LastResultEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh every hour; main app calls WidgetCenter.reloadAllTimelines on spin anyway.
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> LastResultEntry {
        let defaults = UserDefaults(suiteName: Self.groupID)
        return LastResultEntry(
            date: Date(),
            listName: defaults?.string(forKey: "lastListName") ?? "AutoChoice",
            lastResult: defaults?.string(forKey: "lastResult"),
            choiceCount: defaults?.integer(forKey: "lastChoiceCount") ?? 0
        )
    }
}

// MARK: - Widget Views

struct LastResultWidgetEntryView: View {
    let entry: LastResultEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:    smallView
        case .systemMedium:   mediumView
        case .accessoryCircular:   circularView
        case .accessoryRectangular: rectangularView
        case .accessoryInline:     inlineView
        @unknown default:          Text("AutoChoice")
        }
    }

    // MARK: Small (2×2)
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.listName)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(.secondary)
            Spacer()
            Group {
                if let result = entry.lastResult {
                    Text(result)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                } else {
                    Text(LocalizedStringKey("Tap to spin"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.tint)
                Text(LocalizedStringKey("AutoChoice"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
    }

    // MARK: Medium (4×2)
    private var mediumView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.listName)
                    .font(.headline)
                    .lineLimit(1)
                if let result = entry.lastResult {
                    Text(result)
                        .font(.title.weight(.heavy))
                        .foregroundStyle(.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                } else {
                    Text(LocalizedStringKey("Tap to spin"))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                if entry.choiceCount > 0 {
                    Text(String(format: NSLocalizedString("%lld choices", comment: ""), Int64(entry.choiceCount)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "dial.medium")
                .font(.system(size: 56))
                .foregroundStyle(.tint.opacity(0.65))
        }
        .padding()
    }

    // MARK: accessoryCircular (Lock Screen / StandBy circle)
    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let result = entry.lastResult {
                Text(result.prefix(2).uppercased())
                    .font(.title2.weight(.heavy))
            } else {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title2)
            }
        }
    }

    // MARK: accessoryRectangular (Lock Screen rectangle)
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.listName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let result = entry.lastResult {
                Text(result)
                    .font(.headline)
                    .lineLimit(1)
            } else {
                Text(LocalizedStringKey("Tap to spin"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: accessoryInline (Lock Screen inline)
    private var inlineView: some View {
        if let result = entry.lastResult {
            return Text("🎲 \(result)")
        } else {
            return Text("🎲 AutoChoice")
        }
    }
}

// MARK: - Widget Configuration

struct LastResultWidget: Widget {
    let kind: String = "AutoChoiceLastResultWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LastResultProvider()) { entry in
            LastResultWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(LocalizedStringKey("Last result"))
        .description(LocalizedStringKey("Shows your most recent AutoChoice spin"))
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    LastResultWidget()
} timeline: {
    LastResultEntry(date: Date(), listName: "What to eat?", lastResult: "Sushi", choiceCount: 6)
    LastResultEntry(date: Date(), listName: "What to eat?", lastResult: nil, choiceCount: 0)
}
