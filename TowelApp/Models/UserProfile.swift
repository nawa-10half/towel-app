import Foundation
import SwiftUI

struct UserProfile: Equatable {
    var displayName: String
    var iconName: String
    var iconColor: String
    var pinnedBadgeId: String?

    static let defaultIconName = "person.fill"
    static let defaultIconColor = "gray"

    static func `default`(displayName: String = "") -> UserProfile {
        UserProfile(
            displayName: displayName,
            iconName: defaultIconName,
            iconColor: defaultIconColor,
            pinnedBadgeId: nil
        )
    }
}

enum UserProfileIconPalette {
    static let icons: [String] = [
        "person.fill",
        "person.crop.circle.fill",
        "face.smiling",
        "figure.stand",
        "dog.fill",
        "cat.fill",
        "bird.fill",
        "fish.fill",
        "hare.fill",
        "tortoise.fill",
        "lizard.fill",
        "pawprint.fill",
        "heart.fill",
        "star.fill",
        "leaf.fill"
    ]

    static let colors: [(name: String, color: Color)] = [
        ("blue", .blue),
        ("orange", .orange),
        ("green", .green),
        ("pink", .pink),
        ("purple", .purple),
        ("brown", .brown),
        ("gray", .gray)
    ]

    static func color(for name: String) -> Color {
        colors.first { $0.name == name }?.color ?? .gray
    }
}
