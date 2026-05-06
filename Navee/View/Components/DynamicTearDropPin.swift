//
//  DynamicTearDropPin.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import SwiftUI

// MARK: - DynamicTearDropPin

struct DynamicTearDropPin: View {
    let location: Location
    let isSelected: Bool
    let onTap: () -> Void
    let onNavigate: () -> Void

    private var iconName: String { PinIconHelper.iconName(for: location.emoji) }
    private var colors: (top: Color, bottom: Color) { PinIconHelper.colors(for: location.emoji) }

    var body: some View {
        ZStack(alignment: .bottom) {

            if isSelected {
                CalloutBubble(
                    name: location.name,
                    accentColor: colors.top,
                    onNavigate: onNavigate
                )
                .offset(y: -60)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8, anchor: .bottom).combined(with: .opacity),
                    removal:   .scale(scale: 0.8, anchor: .bottom).combined(with: .opacity)
                ))
                .zIndex(10)
            }

            PinBody(iconName: iconName, colors: colors, isSelected: isSelected)
                .onTapGesture { onTap() }
        }
    }
}

// MARK: - PinBody

private struct PinBody: View {
    let iconName: String
    let colors: (top: Color, bottom: Color)
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [colors.top, colors.bottom],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 36, height: 36)

                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }

            PinTail()
                .fill(colors.bottom)
                .frame(width: 12, height: 10)
                .offset(y: -1)
        }
        .scaleEffect(isSelected ? 1.12 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isSelected)
    }
}

// MARK: - PinTail Shape

private struct PinTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - CalloutBubble

private struct CalloutBubble: View {
    let name: String
    let accentColor: Color
    let onNavigate: () -> Void

    private static let bubbleBackground = Color(red: 0.12, green: 0.12, blue: 0.14)

    var body: some View {
        VStack(spacing: 10) {
            Text(name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            navigateButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Self.bubbleBackground.opacity(0.96))
        )
        .overlay(alignment: .bottom) {
            DownwardTriangle()
                .fill(Self.bubbleBackground.opacity(0.96))
                .frame(width: 12, height: 7)
                .offset(y: 6)
        }
        .fixedSize()
    }

    private var navigateButton: some View {
        Button(action: onNavigate) {
            HStack(spacing: 6) {
                Text("Navigate")
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(accentColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(accentColor, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DownwardTriangle Shape

private struct DownwardTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
