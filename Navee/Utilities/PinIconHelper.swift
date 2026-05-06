//
//  PinIconHelper.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import SwiftUI

enum PinIconHelper {

    // Satu sumber kebenaran untuk semua icon yang tersedia
    static let allIcons: [String] = [
        "mappin", "tent.fill", "sun.max.fill", "water.waves",
        "flag.fill", "mountain.2.fill", "flame.fill", "binoculars.fill"
    ]

    static func colors(for emoji: String) -> (top: Color, bottom: Color) {
        switch emoji {
        case "mappin":
            return (.init(red: 0.25, green: 0.55, blue: 1.0),
                    .init(red: 0.08, green: 0.28, blue: 0.86))
        case "tent.fill":
            return (.init(red: 0.22, green: 0.65, blue: 0.38),
                    .init(red: 0.10, green: 0.42, blue: 0.22))
        case "sun.max.fill":
            return (.init(red: 1.0,  green: 0.72, blue: 0.10),
                    .init(red: 0.88, green: 0.50, blue: 0.04))
        case "water.waves":
            return (.init(red: 0.12, green: 0.68, blue: 0.90),
                    .init(red: 0.06, green: 0.44, blue: 0.72))
        case "flag.fill":
            return (.init(red: 1.0,  green: 0.30, blue: 0.22),
                    .init(red: 0.80, green: 0.12, blue: 0.08))
        case "mountain.2.fill":
            return (.init(red: 0.50, green: 0.42, blue: 0.36),
                    .init(red: 0.30, green: 0.24, blue: 0.18))
        case "flame.fill":
            return (.init(red: 1.0,  green: 0.42, blue: 0.12),
                    .init(red: 0.88, green: 0.22, blue: 0.04))
        case "binoculars.fill":
            return (.init(red: 0.40, green: 0.32, blue: 0.80),
                    .init(red: 0.22, green: 0.14, blue: 0.60))
        default:
            return (.init(red: 0.25, green: 0.55, blue: 1.0),
                    .init(red: 0.08, green: 0.28, blue: 0.86))
        }
    }

    /// Shortcut: hanya butuh warna atas (untuk icon picker, row, dll.)
    static func topColor(for emoji: String) -> Color {
        colors(for: emoji).top
    }

    static func iconName(for emoji: String) -> String {
        emoji.isEmpty ? "mappin" : emoji
    }
}
