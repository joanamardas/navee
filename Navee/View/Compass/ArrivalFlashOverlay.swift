//
//  ArrivalFlashOverlay.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import SwiftUI

struct ArrivalFlashOverlay: View {
    let kind: ArrivalKind
    let opacity: Double

    private var accentColor: Color {
        kind == .final
            ? Color(red: 1.0, green: 0.84, blue: 0.04)
            : Color(red: 0.20, green: 0.78, blue: 0.35)
    }
    private var icon: String     { kind == .final ? "flag.checkered.circle.fill" : "checkmark.circle.fill" }
    private var title: String    { kind == .final ? "You've Arrived" : "Checkpoint" }
    private var subtitle: String { kind == .final ? "Destination reached" : "Moving to the next point" }

    var body: some View {
        ZStack {
            Color.black.opacity(opacity * 0.35).ignoresSafeArea()

            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(accentColor)
                    .symbolRenderingMode(.hierarchical)
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .scaleEffect(0.88 + 0.12 * opacity)
            .opacity(opacity)
        }
    }
}
