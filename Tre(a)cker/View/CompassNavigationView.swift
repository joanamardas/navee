//
//  CompassNavigationView.swift
//  Tre(a)cker
//

import SwiftUI
import CoreLocation


// ─────────────────────────────────────────────
// MARK: - Constants
// ─────────────────────────────────────────────

private enum Nav {
    static let arrivalRadius:    Double  = 10
    static let onTrackTolerance: Double  = 30
    static let pinMaxDistance:   Double  = 500
    static let pinMinRatio:      CGFloat = 0.18
}


// ─────────────────────────────────────────────
// MARK: - Navigation State
// ─────────────────────────────────────────────

struct NavState {
    var userHeading: Double = 0
    var bearing:     Double = 0
    var distance:    Double = 0

    var hasArrived: Bool {
        distance > 0 && distance <= Nav.arrivalRadius
    }

    var isOnTrack: Bool {
        guard !hasArrived else { return false }
        return abs(angleDiff(userHeading, bearing)) <= Nav.onTrackTolerance
    }

    private func angleDiff(_ a: Double, _ b: Double) -> Double {
        var d = b - a
        while d >  180 { d -= 360 }
        while d < -180 { d += 360 }
        return d
    }
}


// ─────────────────────────────────────────────
// MARK: - Main View
// ─────────────────────────────────────────────

struct CompassNavigationView: View {
    let allLocations:     [Location]
    let destinationIndex: Int
    var onEndNavigation:  () -> Void

    @StateObject private var tracker = LocationTracker()
    @State private var nav           = NavState()
    @State private var currentStep:  Int = 0

    // ── Breadcrumb path
    // Contoh: 15 titik tersimpan, mau ke titik ke-7 (index 6)
    // breadcrumbPath = [loc[13], loc[12], ..., loc[6]]
    private var breadcrumbPath: [Location] {
        guard destinationIndex < allLocations.count else { return [] }
        let lastIndex = allLocations.count - 1
        guard lastIndex > destinationIndex else {
            return [allLocations[destinationIndex]]
        }
        return (destinationIndex..<lastIndex).reversed().map { allLocations[$0] }
    }

    private var currentTarget: Location? {
        guard currentStep < breadcrumbPath.count else { return nil }
        return breadcrumbPath[currentStep]
    }

    private var totalSteps:   Int  { breadcrumbPath.count }
    private var isLastStep:   Bool { currentStep >= totalSteps - 1 }
    private var finalArrived: Bool { nav.hasArrived && isLastStep }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── GPS Badge
                GPSBadgeView()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                // ── Compass
                if let target = currentTarget {
                    CompassView(nav: nav, destination: target)
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                }

                // ── Status label (tepat di bawah kompas)
                StatusLabel(nav: nav, finalArrived: finalArrived)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                    .animation(.easeInOut(duration: 0.3), value: finalArrived)

                // ── Bottom card
                BottomNavCard(
                    nav:             nav,
                    finalArrived:    finalArrived,
                    currentTarget:   currentTarget,
                    currentStep:     currentStep,
                    totalSteps:      totalSteps,
                    onEndNavigation: onEndNavigation
                )
            }
        }
        .onAppear    { tracker.startTracking() }
        .onDisappear { tracker.stopTracking() }
        .onChange(of: tracker.heading)      { _, h  in nav.userHeading = h }
        .onChange(of: tracker.userLocation) { _, loc in
            updateNav(from: loc)
            checkArrival()
        }
    }

    private func updateNav(from location: CLLocation?) {
        guard let coord = location?.coordinate, let target = currentTarget else { return }
        nav.bearing  = bearing(from: coord, to: target.coordinate)
        nav.distance = distance(from: coord, to: target.coordinate)
    }

    private func checkArrival() {
        guard nav.hasArrived, !isLastStep else { return }
        withAnimation(.easeInOut(duration: 0.4)) { currentStep += 1 }
        updateNav(from: tracker.userLocation)
    }

    private func bearing(from start: CLLocationCoordinate2D,
                         to   end:   CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude  * .pi / 180
        let lat2 = end.latitude    * .pi / 180
        let dLon = (end.longitude - start.longitude) * .pi / 180
        let y    = sin(dLon) * cos(lat2)
        let x    = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    private func distance(from a: CLLocationCoordinate2D,
                          to   b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}


// ─────────────────────────────────────────────
// MARK: - Status Label  (di bawah kompas)
// ─────────────────────────────────────────────

private struct StatusLabel: View {
    let nav:          NavState
    let finalArrived: Bool

    private var label: String {
        if finalArrived   { return "Arrived!" }
        if nav.hasArrived { return "Checkpoint" }
        return nav.isOnTrack ? "On track" : "Wrong way"
    }

    private var subtitle: String {
        if finalArrived   { return "You have reached your destination" }
        if nav.hasArrived { return "Checkpoint reached — moving to next" }
        return nav.isOnTrack ? "Continue toward your destination"
                             : "Head back toward the route"
    }

    private var color: Color {
        if finalArrived   { return Color(red: 1.0,  green: 0.84, blue: 0.04) }
        if nav.hasArrived { return Color(red: 1.0,  green: 0.62, blue: 0.04) }
        return nav.isOnTrack ? Color(red: 0.20, green: 0.78, blue: 0.35)
                             : Color(red: 1.0,  green: 0.23, blue: 0.19)
    }

    var body: some View {
        VStack(spacing: 6) {
            // Badge capsule
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(color)
                    .kerning(0.3)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .background(color.opacity(0.13))
            .clipShape(Capsule())

            // Subtitle
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .animation(.easeInOut(duration: 0.25), value: label)
    }
}


// ─────────────────────────────────────────────
// MARK: - Bottom Nav Card  (Apple-style, compact)
// ─────────────────────────────────────────────

private struct BottomNavCard: View {
    let nav:             NavState
    let finalArrived:    Bool
    let currentTarget:   Location?
    let currentStep:     Int
    let totalSteps:      Int
    var onEndNavigation: () -> Void

    private var statusColor: Color {
        if finalArrived   { return Color(red: 1.0,  green: 0.84, blue: 0.04) }
        if nav.hasArrived { return Color(red: 1.0,  green: 0.62, blue: 0.04) }
        return nav.isOnTrack ? Color(red: 0.20, green: 0.78, blue: 0.35)
                             : Color(red: 1.0,  green: 0.23, blue: 0.19)
    }

    private var distanceFormatted: (value: String, unit: String) {
        let d = nav.distance
        guard d > 0 else { return ("—", "m") }
        if d < 1000 { return ("\(Int(d))", "m") }
        return (String(format: "%.1f", d / 1000), "km")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Drag handle
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 18)

            // ── Destination name (paling besar, yang ditonjolkan)
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
                    .minimumScaleFactor(0.7)
                    .animation(.easeInOut(duration: 0.3), value: currentTarget?.name)
            }
            .padding(.horizontal, 20)

            // Thin separator
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 14)

            // ── Bottom row: distance + progress  |  End button
            HStack(alignment: .center, spacing: 12) {

                VStack(alignment: .leading, spacing: 8) {
                    // Distance
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(distanceFormatted.value)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.35), value: distanceFormatted.value)
                        Text(distanceFormatted.unit)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    // Progress dots (only if multi-step)
                    if totalSteps > 1 {
                        ProgressDotsView(
                            currentStep: currentStep,
                            totalSteps:  totalSteps,
                            activeColor: statusColor
                        )
                    }
                }

                Spacer()

                // End button
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
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(
            Color(red: 0.11, green: 0.11, blue: 0.12)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .ignoresSafeArea(edges: .bottom)
        )
    }
}


// ─────────────────────────────────────────────
// MARK: - Progress Dots
// ─────────────────────────────────────────────

private struct ProgressDotsView: View {
    let currentStep: Int
    let totalSteps:  Int
    let activeColor: Color

    private struct DotItem: Identifiable {
        let id:        Int
        enum Kind { case done, current, next, ellipsis }
        let kind: Kind
    }

    private var items: [DotItem] {
        guard totalSteps > 1 else { return [] }
        if totalSteps <= 7 {
            return (0..<totalSteps).map { i in
                DotItem(id: i, kind: i < currentStep ? .done : i == currentStep ? .current : .next)
            }
        }
        // Condensed view for many steps
        var result: [DotItem] = []
        for i in 0..<2 {
            result.append(DotItem(id: i, kind: i < currentStep ? .done : i == currentStep ? .current : .next))
        }
        result.append(DotItem(id: -1, kind: .ellipsis))
        let mid = max(2, min(currentStep, totalSteps - 3))
        if mid > 1 && mid < totalSteps - 2 {
            result.append(DotItem(id: mid, kind: mid < currentStep ? .done : mid == currentStep ? .current : .next))
            result.append(DotItem(id: -2, kind: .ellipsis))
        }
        for i in (totalSteps - 2)..<totalSteps {
            result.append(DotItem(id: i, kind: i < currentStep ? .done : i == currentStep ? .current : .next))
        }
        return result
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                switch item.kind {
                case .ellipsis:
                    Text("···")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.22))
                case .done:
                    Circle()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 5, height: 5)
                case .current:
                    Circle()
                        .fill(activeColor)
                        .frame(width: 9, height: 9)
                        .animation(.easeInOut(duration: 0.25), value: currentStep)
                case .next:
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 5, height: 5)
                }
            }

            Text("\(currentStep + 1) / \(totalSteps)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.28))
                .padding(.leading, 4)
        }
    }
}


// ─────────────────────────────────────────────
// MARK: - Compass View
// ─────────────────────────────────────────────

fileprivate struct CompassView: View {
    let nav:         NavState
    let destination: Location

    var body: some View {
        GeometryReader { geo in
            let radius = (geo.size.width / 2) * 0.9
            ZStack {
                DirectionCone(nav: nav, radius: radius)
                CompassRing(userHeading: nav.userHeading, radius: radius)
                DestinationPin(nav: nav, radius: radius, destination: destination)
                    .rotationEffect(.degrees(-nav.userHeading))
                UserDot()
            }
            .frame(width: geo.size.width, height: geo.size.width)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}


// ─────────────────────────────────────────────
// MARK: - Compass Sub-views
// ─────────────────────────────────────────────

private struct DirectionCone: View {
    let nav:    NavState
    let radius: CGFloat

    var body: some View {
        ConeSectorShape(halfAngle: Nav.onTrackTolerance)
            .fill(coneGradient)
            .frame(width: radius * 2, height: radius * 2)
    }

    private var coneGradient: RadialGradient {
        let centerColor: Color = nav.hasArrived ? .yellow.opacity(0.5)
                               : nav.isOnTrack  ? .green.opacity(0.45)
                               :                  .white.opacity(0.2)
        return RadialGradient(
            colors: [centerColor, .clear],
            center: UnitPoint(x: 0.5, y: 1.0),
            startRadius: 0,
            endRadius: radius * 2.0
        )
    }
}

private struct CompassRing: View {
    let userHeading: Double
    let radius:      CGFloat

    private let cardinals = [("N", 0.0), ("E", 90.0), ("S", 180.0), ("W", 270.0)]

    var body: some View {
        ZStack {
            ForEach(0..<90, id: \.self) { i in
                let angle    = Double(i) * 4.0
                let isMajor  = i % 23 == 0
                let isMedium = i % 11 == 0 && !isMajor
                let tickLen:   CGFloat = 20
                let tickWidth: CGFloat = isMajor ? 5 : isMedium ? 3.5 : 2.5

                RoundedRectangle(cornerRadius: 0.5)
                    .fill(Color.green.opacity(isMajor ? 1.0 : isMedium ? 0.8 : 0.6))
                    .frame(width: tickWidth, height: tickLen)
                    .offset(y: -(radius + tickLen / 2 + 2))
                    .rotationEffect(.degrees(angle))
            }
            ForEach(cardinals, id: \.0) { label, angle in
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(label == "N" ? .white : .white.opacity(0.6))
                    .offset(y: -(radius + 38))
                    .rotationEffect(.degrees(angle))
            }
        }
        .rotationEffect(.degrees(-userHeading))
    }
}

private struct DestinationPin: View {
    let nav:         NavState
    let radius:      CGFloat
    let destination: Location

    private var pinOffset: CGSize {
        let angleRad  = nav.bearing * .pi / 180
        let ratio     = CGFloat(min(nav.distance, Nav.pinMaxDistance) / Nav.pinMaxDistance)
        let minRadius = radius * Nav.pinMinRatio
        let r         = minRadius + ratio * (radius - minRadius)
        return CGSize(
            width:   CGFloat(sin(angleRad)) * r,
            height: -CGFloat(cos(angleRad)) * r
        )
    }

    private var iconName: String {
        destination.emoji.isEmpty ? "mappin" : destination.emoji
    }

    var body: some View {
        Group {
            if nav.hasArrived {
                TeardropPin(color: .yellow, iconName: "checkmark", iconColor: .black)
            } else if nav.isOnTrack {
                TeardropPin(color: .blue, iconName: iconName, iconColor: .white)
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 10, height: 10)
                    .shadow(color: .blue.opacity(0.4), radius: 4)
            }
        }
        .offset(pinOffset)
    }
}

private struct UserDot: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.15)).frame(width: 22, height: 22)
            Circle().fill(Color.white).frame(width: 14, height: 14)
            Circle().fill(Color.blue).frame(width: 9, height: 9)
        }
    }
}

private struct TeardropPin: View {
    let color:     Color
    let iconName:  String
    let iconColor: Color

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 36, height: 36)
                    .shadow(color: color.opacity(0.5), radius: 6, x: 0, y: 3)
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            TeardropTail()
                .fill(color)
                .frame(width: 12, height: 10)
                .offset(y: -1)
        }
        .offset(y: -(36 + 10) / 2)
    }
}

private struct TeardropTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}


// ─────────────────────────────────────────────
// MARK: - Shapes
// ─────────────────────────────────────────────

private struct ConeSectorShape: Shape {
    let halfAngle: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path   = Path()
        path.move(to: center)
        path.addArc(
            center:     center,
            radius:     radius,
            startAngle: .degrees(-90 - halfAngle),
            endAngle:   .degrees(-90 + halfAngle),
            clockwise:  false
        )
        path.closeSubpath()
        return path
    }
}


// ─────────────────────────────────────────────
// MARK: - GPS Badge
// ─────────────────────────────────────────────

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
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

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


// ─────────────────────────────────────────────
// MARK: - Preview
// ─────────────────────────────────────────────

#Preview {
    let locs = [
        Location(name: "Titik 1", coordinate: .init(latitude: -6.291, longitude: 106.643), altitude: 10, emoji: "mappin",    notes: ""),
        Location(name: "Titik 2", coordinate: .init(latitude: -6.292, longitude: 106.644), altitude: 20, emoji: "tent.fill", notes: ""),
        Location(name: "Titik 3", coordinate: .init(latitude: -6.293, longitude: 106.645), altitude: 30, emoji: "flag.fill", notes: ""),
        Location(name: "Titik 4", coordinate: .init(latitude: -6.294, longitude: 106.646), altitude: 40, emoji: "flame.fill",notes: ""),
    ]
    CompassNavigationView(
        allLocations:     locs,
        destinationIndex: 1,
        onEndNavigation:  {}
    )
}
