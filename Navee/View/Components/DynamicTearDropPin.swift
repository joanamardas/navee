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
    
    private var iconName: String { PinIconHelper.iconName(for: location.emoji) }
    private var colors: (top: Color, bottom: Color) { PinIconHelper.colors(for: location.emoji) }
    
    var body: some View {
        PinBody(iconName: iconName, colors: colors, isSelected: isSelected)
            .onTapGesture { onTap() }
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
