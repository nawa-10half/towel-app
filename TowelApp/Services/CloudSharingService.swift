import SwiftUI
import CloudKit

struct CloudSharingView: View {
    @State private var sharingStatus = "iCloud共有の設定は実機でのみ利用可能です"

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "icloud.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("iCloud共有")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(sharingStatus)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    sharingStep(number: 1, text: "iCloudにサインインしていることを確認")
                    sharingStep(number: 2, text: "共有したい相手にリンクを送信")
                    sharingStep(number: 3, text: "相手がリンクを開くとデータが同期されます")
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("データ共有")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func sharingStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    CloudSharingView()
}
