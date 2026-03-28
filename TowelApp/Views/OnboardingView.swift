import SwiftUI

private struct OnboardingPage {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let color: Color
}

private let onboardingPages: [OnboardingPage] = {
    var pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "drop.fill",
            title: "交換のタイミングを\n見える化",
            description: "アイテムごとに交換間隔を設定すると、\n余裕あり・もうすぐ・超過をひと目で把握できます。",
            color: .blue
        ),
        OnboardingPage(
            icon: "camera.fill",
            title: "AIがタオルの\n状態を診断",
            description: "写真を撮るだけで、色あせ・汚れ・\nふわふわ感・ほつれをAIが自動採点します。",
            color: .indigo
        ),
        OnboardingPage(
            icon: "person.3.sequence.fill",
            title: "家族と\nシェアできる",
            description: "招待コードで家族グループを作成。\n誰かが交換を記録すれば全員の画面に即反映。",
            color: .teal
        ),
    ]
    if Locale.current.language.languageCode == .japanese {
        pages.append(OnboardingPage(
            icon: "mic.fill",
            title: "Alexaで\nハンズフリー管理",
            description: "「アレクサ、かえたおアプリで状態教えて」\nと声だけで確認・記録ができます。",
            color: .orange
        ))
    }
    return pages
}()

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(onboardingPages.indices, id: \.self) { index in
                OnboardingPageView(
                    page: onboardingPages[index],
                    isLast: index == onboardingPages.count - 1,
                    onComplete: { hasSeenOnboarding = true }
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .ignoresSafeArea()
        .animation(.easeInOut, value: currentPage)
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let isLast: Bool
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            page.color.opacity(0.07).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // アイコン
                ZStack {
                    Circle()
                        .fill(page.color.opacity(0.15))
                        .frame(width: 128, height: 128)
                    Image(systemName: page.icon)
                        .font(.system(size: 54))
                        .foregroundStyle(page.color)
                }
                .padding(.bottom, 40)

                // テキスト
                VStack(spacing: 16) {
                    Text(page.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(page.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                }

                Spacer()

                // 最終ページのみ「はじめる」ボタンを表示
                if isLast {
                    Button(action: onComplete) {
                        Text("はじめる")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(page.color)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 60)
                } else {
                    Spacer().frame(height: 114) // ボタン高さ分のスペースを確保してドットを固定
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
}
