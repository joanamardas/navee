//
//  IconPicker.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import SwiftUI

// MARK: - IconPicker

struct IconPicker: View {
    @Binding var selectedIcon: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(PinIconHelper.allIcons, id: \.self) { icon in
                    IconPickerCell(
                        icon: icon,
                        isSelected: selectedIcon == icon
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                            selectedIcon = icon
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - IconPickerCell

private struct IconPickerCell: View {
    let icon: String
    let isSelected: Bool
    let onSelect: () -> Void

    private var color: Color { PinIconHelper.topColor(for: icon) }

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? color : Color.white.opacity(0.07))
                    .frame(width: 44, height: 44)

                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(color.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 44, height: 44)
                }

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .secondary)
            }
            .scaleEffect(isSelected ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isSelected)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var selected = "mappin"
    return Form { IconPicker(selectedIcon: $selected) }
        .preferredColorScheme(.dark)
}
