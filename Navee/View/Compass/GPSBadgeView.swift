//
//  GPSBadgeView.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import SwiftUI

struct GPSBadgeView: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 11))
            Text("GPS:")
                .font(.system(size: 11, weight: .semibold))
            SignalBars()
        }
        .foregroundColor(.green)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.green.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - SignalBars

private struct SignalBars: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .frame(width: 3.5, height: CGFloat(5 + i * 3))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    GPSBadgeView().padding().background(Color.black)
}
