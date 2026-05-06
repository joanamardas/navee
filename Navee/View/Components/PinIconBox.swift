//
//  PinIconBox.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import SwiftUI

struct PinIconBox: View {
    let emoji: String
    var size: CGFloat = 40
    var iconSize: CGFloat = 18

    private var colors: (top: Color, bottom: Color) {
        PinIconHelper.colors(for: PinIconHelper.iconName(for: emoji))
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .fill(LinearGradient(
                    colors: [colors.top, colors.bottom],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: size, height: size)

            Image(systemName: PinIconHelper.iconName(for: emoji))
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 12) {
        ForEach(PinIconHelper.allIcons, id: \.self) { icon in
            PinIconBox(emoji: icon)
        }
    }
    .padding()
    .background(Color.black)
}
