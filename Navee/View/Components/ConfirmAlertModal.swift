//
//  ConfirmAlertModal.swift
//  Navee
//
//  Created by neena on 07/05/26.
//

import SwiftUI

struct ConfirmAlertModal: View {
    let icon: String
    let iconTint: Color
    let title: String
    let message: String
    let confirmLabel: String
    let confirmTint: Color
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            // Dim backdrop
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            // Modal box
            VStack(spacing: 0) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconTint.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(
                            iconTint,
                            iconTint.opacity(0.2)
                        )
                }
                .padding(.top, 28)
                .padding(.bottom, 14)

                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text(message)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.top, 6)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 1)

                HStack(spacing: 0) {
                    Button {
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(ModalButtonStyle())

                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 1, height: 52)

                    Button {
                        onConfirm()
                    } label: {
                        Text(confirmLabel)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(confirmTint)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(ModalButtonStyle())
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(red: 0.14, green: 0.14, blue: 0.15).opacity(0.7))
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.75)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 48)
            .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 10)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.93)))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ConfirmAlertModal(
            icon: "xmark.circle.fill",
            iconTint: Color(red: 1.0, green: 0.33, blue: 0.30),
            title: "End Navigation?",
            message: "Your current navigation session\nwill be stopped.",
            confirmLabel: "End",
            confirmTint: Color(red: 1.0, green: 0.33, blue: 0.30),
            onCancel: {},
            onConfirm: {}
        )
    }
}
