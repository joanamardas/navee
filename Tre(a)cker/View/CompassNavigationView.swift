// CompassNavigationView.swift
// Layar navigasi kompas — mengarahkan user ke pin tujuan step by step.

import SwiftUI
import CoreLocation

// MARK: - Konstanta Navigasi

private enum Nav {
    static let arrivalRadius: Double    = 10
    static let onTrackTolerance: Double = 30
    static let pinMaxDistance: Double   = 500
    static let pinMinRatio: CGFloat     = 0.18
}

// MARK: - Navigation State

struct NavState {
    var userHeading: Double = 0
    var bearing: Double     = 0
    var distance: Double    = 0

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

// MARK: - Arrival Flash State

private enum ArrivalKind { case checkpoint, final }

// MARK: - Icon/Color helper (mirrors SavedMarkRow & ModifyPin)

private func pinIconColor(for emoji: String) -> Color {
    switch emoji {
    case "mappin":          return Color(red: 0.25, green: 0.55, blue: 1.0)
    case "tent.fill":       return Color(red: 0.22, green: 0.65, blue: 0.38)
    case "sun.max.fill":    return Color(red: 1.0,  green: 0.72, blue: 0.10)
    case "water.waves":     return Color(red: 0.12, green: 0.68, blue: 0.90)
    case "flag.fill":       return Color(red: 1.0,  green: 0.30, blue: 0.22)
    case "mountain.2.fill": return Color(red: 0.50, green: 0.42, blue: 0.36)
    case "flame.fill":      return Color(red: 1.0,  green: 0.42, blue: 0.12)
    case "binoculars.fill": return Color(red: 0.40, green: 0.32, blue: 0.80)
    default:                return Color(red: 0.25, green: 0.55, blue: 1.0)
    }
}

private func pinIconName(for emoji: String) -> String {
    emoji.isEmpty ? "mappin" : emoji
}

// MARK: - CompassNavigationView

struct CompassNavigationView: View {
    let allLocations: [Location]
    let destinationIndex: Int
    var onEndNavigation: () -> Void

    @StateObject private var tracker = LocationTracker()
    @State private var nav = NavState()
    @State private var currentStep = 0

    // Arrival flash overlay
    @State private var arrivalFlash: ArrivalKind? = nil
    @State private var flashOpacity: Double = 0

    private var breadcrumbs: [Location] {
        guard destinationIndex < allLocations.count else { return [] }
        let last = allLocations.count - 1
        guard last > destinationIndex else { return [allLocations[destinationIndex]] }
        return (destinationIndex..<last).reversed().map { allLocations[$0] }
    }

    private var currentTarget: Location? { breadcrumbs[safe: currentStep] }
    private var totalSteps: Int          { breadcrumbs.count }
    private var isLastStep: Bool         { currentStep >= totalSteps - 1 }
    private var finalArrived: Bool       { nav.hasArrived && isLastStep }

    private var pointsPassed: Int {
        if nav.hasArrived { return currentStep + 1 }
        return currentStep
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                GPSBadgeView()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                Spacer(minLength: 0)

                VStack(spacing: 0) {
                    if let target = currentTarget {
                        CompassView(nav: nav, destination: target)
                            .padding(.horizontal, 32)
                    }
                    StatusLabel(nav: nav, finalArrived: finalArrived)
                        .padding(.top, 16)
                        .animation(.easeInOut(duration: 0.3), value: finalArrived)
                }

                Spacer(minLength: 16)

                BottomNavCard(
                    nav:             nav,
                    finalArrived:    finalArrived,
                    currentTarget:   currentTarget,
                    pointsPassed:    pointsPassed,
                    totalSteps:      totalSteps,
                    onEndNavigation: onEndNavigation
                )
            }

            // ── Arrival flash overlay
            if arrivalFlash != nil {
                ArrivalFlashOverlay(kind: arrivalFlash!, opacity: flashOpacity)
                    .allowsHitTesting(false)
            }
        }
        .onAppear    { tracker.startTracking() }
        .onDisappear { tracker.stopTracking() }
        .onChange(of: tracker.heading)      { _, h   in nav.userHeading = h }
        .onChange(of: tracker.userLocation) { _, loc in
            updateNav(from: loc)
            checkArrival()
        }
    }

    // MARK: - Helpers

    private func updateNav(from location: CLLocation?) {
        guard let coord = location?.coordinate, let target = currentTarget else { return }
        nav.bearing  = bearing(from: coord, to: target.coordinate)
        nav.distance = distance(from: coord, to: target.coordinate)
    }

    private func checkArrival() {
        guard nav.hasArrived else { return }

        if isLastStep {
            triggerFlash(.final)
        } else {
            triggerFlash(.checkpoint) {
                withAnimation(.easeInOut(duration: 0.4)) { currentStep += 1 }
                updateNav(from: tracker.userLocation)
            }
        }
    }

    private func triggerFlash(_ kind: ArrivalKind, completion: (() -> Void)? = nil) {
        guard arrivalFlash == nil else { return }
        arrivalFlash = kind
        withAnimation(.easeOut(duration: 0.2)) { flashOpacity = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeIn(duration: 0.35)) { flashOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                arrivalFlash = nil
                completion?()
            }
        }
    }

    private func bearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude  * .pi / 180
        let lat2 = end.latitude    * .pi / 180
        let dLon = (end.longitude - start.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    private func distance(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Arrival Flash Overlay
// Clean, Apple-like — no glow, frosted card, minimal animation.

private struct ArrivalFlashOverlay: View {
    let kind: ArrivalKind
    let opacity: Double

    private var accentColor: Color {
        kind == .final ? Color(red: 1.0, green: 0.84, blue: 0.04) : Color(red: 0.20, green: 0.78, blue: 0.35)
    }

    private var icon: String {
        kind == .final ? "flag.checkered.circle.fill" : "checkmark.circle.fill"
    }

    private var title: String {
        kind == .final ? "You've Arrived" : "Checkpoint"
    }

    private var subtitle: String {
        kind == .final ? "Destination reached" : "Moving to the next point"
    }

    var body: some View {
        ZStack {
            // Subtle dark scrim — no color bleed
            Color.black
                .opacity(opacity * 0.35)
                .ignoresSafeArea()

            // Frosted card — iOS 26 vibes: ultra-thin material feel
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(accentColor)
                    .symbolRenderingMode(.hierarchical)

                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .scaleEffect(0.88 + 0.12 * opacity)
            .opacity(opacity)
        }
    }
}

// MARK: - Status Label

private struct StatusLabel: View {
    let nav: NavState
    let finalArrived: Bool

    private var label: String {
        if finalArrived   { return "Arrived" }
        if nav.hasArrived { return "Checkpoint" }
        return nav.isOnTrack ? "On Track" : "Wrong Way"
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
        // On track = green, wrong way = white
        return nav.isOnTrack ? Color(red: 0.20, green: 0.78, blue: 0.35) : .white
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(color)
                    .kerning(0.3)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .background(color.opacity(0.13))
            .clipShape(Capsule())

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .animation(.easeInOut(duration: 0.25), value: label)
    }
}

// MARK: - Compass View

private struct CompassView: View {
    let nav: NavState
    let destination: Location

    var body: some View {
        GeometryReader { geo in
            let size   = geo.size.width
            let radius = size / 2
            ZStack {
                DirectionCone(nav: nav, radius: radius)
                CompassDial(nav: nav, radius: radius)
                    .frame(width: size, height: size)
                DestinationPin(nav: nav, radius: radius * 0.9, destination: destination)
                    .rotationEffect(.degrees(-nav.userHeading))
                NorthPointer(radius: radius)
                UserDot()
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Compass Dial
// Ticks are white when wrong way, green when on track (matching cone color).

private struct CompassDial: View {
    let nav: NavState
    let radius: CGFloat

    private var tickAccentColor: Color {
        if nav.hasArrived { return Color(red: 1.0, green: 0.84, blue: 0.04) }
        return nav.isOnTrack ? .green : .white
    }

    private let cardinalLabels: [(text: String, deg: Double, major: Bool)] = [
        ("N", 0, true), ("NE", 45, false), ("E", 90, true),
        ("SE", 135, false), ("S", 180, true), ("SW", 225, false),
        ("W", 270, true), ("NW", 315, false)
    ]

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width  / 2
            let cy = size.height / 2
            let R  = min(cx, cy)

            let ring = Path(ellipseIn: CGRect(x: cx - R, y: cy - R, width: R * 2, height: R * 2))
            ctx.stroke(ring, with: .color(.white.opacity(0.08)), lineWidth: 1)

            // Resolve accent color inside Canvas
            let accentIsGreen = nav.isOnTrack && !nav.hasArrived
            let accentIsYellow = nav.hasArrived

            for deg in stride(from: 0.0, to: 360.0, by: 2.0) {
                let isMajor  = deg.truncatingRemainder(dividingBy: 90) == 0
                let isCard   = deg.truncatingRemainder(dividingBy: 45) == 0 && !isMajor
                let isMedium = deg.truncatingRemainder(dividingBy: 10) == 0 && !isCard && !isMajor

                let outer: CGFloat = R - 2
                let inner: CGFloat = isMajor ? R - 22 : isCard ? R - 16 : isMedium ? R - 11 : R - 7

                let rad = (deg - nav.userHeading - 90) * .pi / 180
                let cosV = CGFloat(Foundation.cos(rad))
                let sinV = CGFloat(Foundation.sin(rad))

                var tick = Path()
                tick.move(to:    CGPoint(x: cx + outer * cosV, y: cy + outer * sinV))
                tick.addLine(to: CGPoint(x: cx + inner * cosV, y: cy + inner * sinV))

                let width:   CGFloat = isMajor ? 2.5 : isCard ? 2.0 : isMedium ? 1.5 : 1.0
                let opacity: Double  = isMajor ? 1.0 : isCard ? 0.8 : isMedium ? 0.55 : 0.3

                // N tick = always white; others follow accent
                let color: Color
                if deg == 0 {
                    color = .white
                } else if accentIsYellow {
                    color = Color(red: 1.0, green: 0.84, blue: 0.04)
                } else if accentIsGreen {
                    color = .green
                } else {
                    color = .white
                }

                ctx.stroke(tick, with: .color(color.opacity(opacity)),
                           style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
        }
        .overlay(
            ZStack {
                ForEach(cardinalLabels, id: \.deg) { item in
                    let rad  = (item.deg - nav.userHeading) * .pi / 180
                    let dist = radius - (item.major ? 32 : 26)
                    Text(item.text)
                        .font(.system(size: item.major ? 13 : 10,
                                      weight: item.major ? .bold : .medium,
                                      design: .rounded))
                        .foregroundColor(
                            item.deg == 0 ? .white
                            : item.major  ? .white.opacity(0.85)
                            :               .white.opacity(0.4)
                        )
                        .offset(
                            x: CGFloat(sin(rad))  * dist,
                            y: -CGFloat(cos(rad)) * dist
                        )
                }
            }
        )
    }
}

// MARK: - North Pointer

private struct NorthPointer: View {
    let radius: CGFloat
    var body: some View {
        ArrowTriangle()
            .fill(Color.red)
            .frame(width: 8, height: 14)
            .offset(y: -(radius - 4))
    }
}

private struct ArrowTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Direction Cone
// Wrong way = white/muted cone, on track = green cone.

private struct DirectionCone: View {
    let nav: NavState
    let radius: CGFloat

    var body: some View {
        ConeSectorShape(halfAngle: Nav.onTrackTolerance)
            .fill(coneGradient)
            .frame(width: radius * 2, height: radius * 2)
    }

    private var coneGradient: RadialGradient {
        let centerColor: Color
        if nav.hasArrived {
            centerColor = Color(red: 1.0, green: 0.84, blue: 0.04).opacity(0.35)
        } else if nav.isOnTrack {
            centerColor = .green.opacity(0.35)
        } else {
            // Wrong way — subtle white/grey cone
            centerColor = .white.opacity(0.14)
        }
        return RadialGradient(
            colors: [centerColor, .clear],
            center: UnitPoint(x: 0.5, y: 1.0),
            startRadius: 0,
            endRadius: radius * 2.2
        )
    }
}

private struct ConeSectorShape: Shape {
    let halfAngle: Double
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: r,
                    startAngle: .degrees(-90 - halfAngle),
                    endAngle:   .degrees(-90 + halfAngle),
                    clockwise:  false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Destination Pin
// Uses the location's actual icon + brand color (matches SavedMarkRow & ModifyPin).

private struct DestinationPin: View {
    let nav: NavState
    let radius: CGFloat
    let destination: Location

    private var pinOffset: CGSize {
        let angleRad = nav.bearing * .pi / 180
        let ratio    = CGFloat(min(nav.distance, Nav.pinMaxDistance) / Nav.pinMaxDistance)
        let minR     = radius * Nav.pinMinRatio
        let r        = minR + ratio * (radius - minR)
        return CGSize(
            width:  CGFloat(sin(angleRad)) * r,
            height: -CGFloat(cos(angleRad)) * r
        )
    }

    private var iconName: String { pinIconName(for: destination.emoji) }
    private var iconColor: Color { pinIconColor(for: destination.emoji) }

    var body: some View {
        Group {
            if nav.hasArrived {
                // Arrived: show actual pin icon (not yellow checkmark)
                TeardropPin(color: iconColor, iconName: iconName, iconColor: .white)
            } else if nav.isOnTrack {
                TeardropPin(color: iconColor, iconName: iconName, iconColor: .white)
            } else {
                // Wrong way — dimmed dot, same color family
                Circle()
                    .fill(iconColor.opacity(0.5))
                    .frame(width: 10, height: 10)
            }
        }
        .offset(pinOffset)
    }
}

// MARK: - User Dot

private struct UserDot: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.12)).frame(width: 22, height: 22)
            Circle().fill(Color.white).frame(width: 13, height: 13)
            Circle().fill(Color.blue).frame(width: 8,  height: 8)
        }
    }
}

// MARK: - Teardrop Pin

private struct TeardropPin: View {
    let color: Color
    let iconName: String
    let iconColor: Color

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 34, height: 34)
                    .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            TeardropTail()
                .fill(color)
                .frame(width: 11, height: 9)
                .offset(y: -1)
        }
        .offset(y: -(34 + 9) / 2)
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

// MARK: - Bottom Nav Card
// Anchored flush to the screen bottom — no floating gap.

private struct BottomNavCard: View {
    let nav: NavState
    let finalArrived: Bool
    let currentTarget: Location?
    let pointsPassed: Int
    let totalSteps: Int
    var onEndNavigation: () -> Void

    private var statusColor: Color {
        if finalArrived   { return Color(red: 1.0,  green: 0.84, blue: 0.04) }
        if nav.hasArrived { return Color(red: 1.0,  green: 0.62, blue: 0.04) }
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

            // ── Hero: destination name
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
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // ── Progress dots
            if totalSteps > 1 {
                ProgressDotsView(
                    currentStep: pointsPassed - 1,
                    totalSteps:  totalSteps,
                    activeColor: statusColor
                )
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }

            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)
                .padding(.horizontal, 20)
                .padding(.top, 14)

            // ── Distance + End button
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
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
            .padding(.horizontal, 20)
            .padding(.top, 14)
            // Use safeAreaInsets bottom padding so card content isn't hidden under home indicator,
            // but the background itself bleeds to the true bottom edge.
            .padding(.bottom, 16)
        }
        .background(
            Color(red: 0.11, green: 0.11, blue: 0.12)
                .ignoresSafeArea(edges: .bottom)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 24,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 24,
                        style: .continuous
                    )
                )
        )
    }
}

// MARK: - Progress Dots

private struct ProgressDotsView: View {
    let currentStep: Int
    let totalSteps: Int
    let activeColor: Color

    private enum DotKind { case done, current, next, ellipsis }
    private struct DotItem: Identifiable {
        let id: Int
        let kind: DotKind
    }

    private var items: [DotItem] {
        guard totalSteps > 1 else { return [] }
        if totalSteps <= 7 {
            return (0..<totalSteps).map { i in
                DotItem(id: i, kind: i < currentStep ? .done : i == currentStep ? .current : .next)
            }
        }
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

// MARK: - GPS Badge

struct GPSBadgeView: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 11))
            Text("GPS:").font(.system(size: 11, weight: .semibold))
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
    let locs = [
        Location(name: "Titik 1", coordinate: .init(latitude: -6.291, longitude: 106.643), altitude: 10, emoji: "mappin",     notes: ""),
        Location(name: "Titik 2", coordinate: .init(latitude: -6.292, longitude: 106.644), altitude: 20, emoji: "tent.fill",  notes: ""),
        Location(name: "Titik 3", coordinate: .init(latitude: -6.293, longitude: 106.645), altitude: 30, emoji: "flag.fill",  notes: ""),
        Location(name: "Titik 4", coordinate: .init(latitude: -6.294, longitude: 106.646), altitude: 40, emoji: "flame.fill", notes: ""),
    ]
    CompassNavigationView(allLocations: locs, destinationIndex: 1, onEndNavigation: {})
}
