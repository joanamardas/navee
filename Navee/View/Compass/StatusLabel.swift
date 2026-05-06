//
//  StatusLabel.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import SwiftUI

struct StatusLabel: View {
    let nav: NavState
    let finalArrived: Bool

    private var noGPS: Bool { nav.distance == 0 || !nav.hasValidHeading }

    private var label: String {
        if noGPS        { return "Searching GPS…" }
        if finalArrived { return "Arrived!" }
        return nav.isOnTrack ? "On Track" : "Wrong Way"
    }

    private var subtitle: String {
        if noGPS        { return "Waiting for location signal" }
        if finalArrived { return "You have reached your destination" }
        return nav.isOnTrack
            ? "Continue toward your destination"
            : "Head back toward the route"
    }

    private var dotColor: Color {
        if noGPS        { return .white.opacity(0.35) }
        if finalArrived { return Color(red: 1.0, green: 0.84, blue: 0.04) }
        return nav.isOnTrack
            ? Color(red: 0.20, green: 0.78, blue: 0.35)
            : Color(red: 1.0,  green: 0.27, blue: 0.23)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Circle().fill(dotColor).frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(dotColor)
                    .kerning(0.3)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .background(dotColor.opacity(0.13))
            .clipShape(Capsule())

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .animation(.easeInOut(duration: 0.25), value: label)
    }
}
