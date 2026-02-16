import SwiftUI
import WidgetKit

struct CircularWidgetView: View {
    let entry: TowelWidgetEntry

    private var needsExchangeCount: Int {
        entry.towels.filter { $0.status == .overdue || $0.status == .soon }.count
    }

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                if needsExchangeCount > 0 {
                    Text("\(needsExchangeCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("要交換")
                        .font(.system(size: 9))
                        .widgetAccentable()
                } else {
                    Image(systemName: "checkmark")
                        .font(.title3)
                    Text("OK")
                        .font(.system(size: 10))
                }
            }
        }
    }
}
