import SwiftUI

struct SparkleOverlay: View {
    var color: Color = .white
    var shadowColor: Color = .green
    var sparkles: [(x: CGFloat, y: CGFloat, size: CGFloat, delay: Double)]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(sparkles.indices, id: \.self) { i in
                let s = sparkles[i]
                SparkleDot(x: s.x, y: s.y, size: s.size, startDelay: s.delay, color: color, shadowColor: shadowColor)
            }
        }
        .allowsHitTesting(false)
    }
}

struct SparkleDot: View {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let startDelay: Double
    var color: Color = .white
    var shadowColor: Color = .green

    @State private var visible = false

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(color)
            .shadow(color: shadowColor.opacity(0.6), radius: 2)
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1.1 : 0.4)
            .position(x: x, y: y)
            .task {
                try? await Task.sleep(for: .milliseconds(Int((startDelay + 0.08) * 1000)))
                for _ in 0..<2 {
                    withAnimation(.easeOut(duration: 0.4)) { visible = true }
                    try? await Task.sleep(for: .milliseconds(450))
                    withAnimation(.easeIn(duration: 0.5)) { visible = false }
                    try? await Task.sleep(for: .milliseconds(280))
                }
            }
            .onDisappear { visible = false }
    }
}
