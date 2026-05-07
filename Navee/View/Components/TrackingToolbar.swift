//
//  TrackingToolbar.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import SwiftUI

struct TrackingToolbar: View {
    let pinCount: Int
    let onShowMarks: () -> Void
    let onAddMark: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 14) {
                savedMarksButton
                addMarkButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
    }

    // MARK: - Subviews

    private var savedMarksButton: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onShowMarks) {
                ZStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 64, height: 64)
                    Circle()
                        .fill(LinearGradient(
                            colors: [.white.opacity(0.28), .clear],
                            startPoint: .top,
                            endPoint: .center
                        ))
                        .frame(width: 64, height: 64)
                    Image(systemName: "mappin")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(GlassButtonStyle())

            if pinCount > 0 {
                PinCountBadge(count: pinCount)
                    .offset(x: 4, y: -4)
            }
        }
    }

    private var addMarkButton: some View {
        Button(action: onAddMark) {
            ZStack {
                Capsule().fill(Color(red: 0.18, green: 0.45, blue: 1.0))
                Capsule().fill(LinearGradient(
                    colors: [.white.opacity(0.22), .clear],
                    startPoint: .top,
                    endPoint: .center
                ))
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                    Text("Add Mark")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
            }
            .frame(height: 64)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(GlassButtonStyle())
    }
}

// MARK: - PinCountBadge

private struct PinCountBadge: View {
    let count: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.18, green: 0.78, blue: 0.35))
                .frame(width: 24, height: 24)
            Text("\(min(count, 99))")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}
