//
//  BottomNavCard.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import SwiftUI

// MARK: - BottomNavCard

struct BottomNavCard: View {
    let nav: NavState
    let finalArrived: Bool
    let currentTarget: Location?
    let pointsPassed: Int
    let totalSteps: Int
    var onEndNavigation: () -> Void

    private var statusColor: Color {
        if nav.hasArrived { return Color(red: 1.0, green: 0.84, blue: 0.04) }
        return nav.isOnTrack ? Color(red: 0.20, green: 0.78, blue: 0.35) : .white
    }

    private var distanceText: (value: String, unit: String) {
        let d = nav.distance
        guard d > 0 else { return ("—", "m") }
        return d < 1000
            ? ("\(Int(d))", "m")
            : (String(format: "%.1f", d / 1000), "km")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            destinationHeader
                .padding(.horizontal, 20)
                .padding(.top, 20)

            if totalSteps > 1 {
                ProgressDotsView(
                    currentStep: pointsPassed - 1,
                    totalSteps: totalSteps,
                    activeColor: statusColor
                )
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }

            Divider()
                .background(Color.white.opacity(0.07))
                .padding(.horizontal, 20)
                .padding(.top, 14)

            distanceAndEndRow
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 16)
        }
        .background(Color(red: 0.11, green: 0.11, blue: 0.12).ignoresSafeArea(edges: .bottom))
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 24, bottomLeadingRadius: 0,
            bottomTrailingRadius: 0, topTrailingRadius: 24,
            style: .continuous
        ))
    }

    // MARK: - Subviews

    private var destinationHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("navigating to")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.32))
                .textCase(.uppercase)
                .kerning(0.5)
            Text(currentTarget?.name ?? "—")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .animation(.easeInOut(duration: 0.3), value: currentTarget?.name)
        }
    }

    private var distanceAndEndRow: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(distanceText.value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.35), value: distanceText.value)
                Text(distanceText.unit)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))
            }
            Spacer()
            Button(action: onEndNavigation) {
                Text("End")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 13)
                    .background(Color(red: 1.0, green: 0.23, blue: 0.19))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - ProgressDotsView

private struct ProgressDotsView: View {
    let currentStep: Int
    let totalSteps: Int
    let activeColor: Color

    private enum DotKind { case done, current, next, ellipsis }
    private struct DotItem: Identifiable { let id: Int; let kind: DotKind }

    private func dotKind(at i: Int) -> DotKind {
        i < currentStep ? .done : i == currentStep ? .current : .next
    }

    private var items: [DotItem] {
        guard totalSteps > 1 else { return [] }
        if totalSteps <= 7 {
            return (0..<totalSteps).map { DotItem(id: $0, kind: dotKind(at: $0)) }
        }
        var result = (0..<2).map { DotItem(id: $0, kind: dotKind(at: $0)) }
        result.append(DotItem(id: -1, kind: .ellipsis))
        let mid = max(2, min(currentStep, totalSteps - 3))
        if mid > 1 && mid < totalSteps - 2 {
            result.append(DotItem(id: mid, kind: dotKind(at: mid)))
            result.append(DotItem(id: -2, kind: .ellipsis))
        }
        result += (totalSteps - 2..<totalSteps).map { DotItem(id: $0, kind: dotKind(at: $0)) }
        return result
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                switch item.kind {
                case .ellipsis:
                    Text("···").font(.system(size: 9, weight: .bold)).foregroundColor(.white.opacity(0.22))
                case .done:
                    Circle().fill(Color.white.opacity(0.35)).frame(width: 5, height: 5)
                case .current:
                    Circle().fill(activeColor).frame(width: 9, height: 9)
                        .animation(.easeInOut(duration: 0.25), value: currentStep)
                case .next:
                    Circle().fill(Color.white.opacity(0.15)).frame(width: 5, height: 5)
                }
            }
            Text("\(currentStep + 1) of \(totalSteps) points passed")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.28))
                .padding(.leading, 4)
        }
    }
}
