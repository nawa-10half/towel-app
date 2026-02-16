import WidgetKit
import SwiftUI

struct TowelWidget: Widget {
    let kind: String = "TowelWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TowelWidgetProvider()) { entry in
            TowelWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("タオル交換")
        .description("タオルの交換タイミングを確認できます")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular,
        ])
    }
}

struct TowelWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: TowelWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryInline:
            InlineWidgetView(entry: entry)
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
        case .accessoryRectangular:
            RectangularWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

#Preview(as: .systemSmall) {
    TowelWidget()
} timeline: {
    TowelWidgetEntry.placeholder
}

#Preview(as: .systemMedium) {
    TowelWidget()
} timeline: {
    TowelWidgetEntry.placeholder
}

#Preview(as: .accessoryInline) {
    TowelWidget()
} timeline: {
    TowelWidgetEntry.placeholder
}

#Preview(as: .accessoryCircular) {
    TowelWidget()
} timeline: {
    TowelWidgetEntry.placeholder
}

#Preview(as: .accessoryRectangular) {
    TowelWidget()
} timeline: {
    TowelWidgetEntry.placeholder
}
