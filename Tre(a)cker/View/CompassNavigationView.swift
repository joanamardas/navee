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
    static let arrivalRadius:   Double  = 10    // meter — dianggap sudah sampai
    static let onTrackTolerance: Double = 30    // derajat — batas "arah benar"
    static let pinMaxDistance:  Double  = 500   // meter — jarak maks untuk posisi pin
    static let pinMinRatio:     CGFloat = 0.18  // posisi pin paling dekat ke tengah
}


// ─────────────────────────────────────────────
// MARK: - Navigation State
// ─────────────────────────────────────────────

/// Semua state navigasi dikumpulkan di sini supaya View lebih bersih.
struct NavState {
    var userHeading: Double = 0   // arah hadap user (dari kompas)
    var bearing:     Double = 0   // arah ke tujuan (dihitung dari koordinat)
    var distance:    Double = 0   // jarak ke tujuan dalam meter

    var hasArrived: Bool {
        distance > 0 && distance <= Nav.arrivalRadius
    }

    var isOnTrack: Bool {
        guard !hasArrived else { return false }
        return abs(angleDiff(userHeading, bearing)) <= Nav.onTrackTolerance
    }

    /// Selisih sudut terpendek antara dua arah (hasil: -180 … +180).
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
    let destination:    Location
    var onEndNavigation: () -> Void

    @StateObject private var tracker = LocationTracker()
    @State private var nav = NavState()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                GPSBadgeView()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                StatusLabel(hasArrived: nav.hasArrived, isOnTrack: nav.isOnTrack)
                    .padding(.vertical, 48)

                CompassView(nav: nav)
                    .padding(.horizontal, 32)

                Spacer()

                BottomCard(
                    name: destination.name,
                    distance: nav.distance,
                    onEnd: onEndNavigation
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
        }
        .onAppear  { tracker.startTracking() }
        .onDisappear { tracker.stopTracking() }
        .onChange(of: tracker.heading)      { _, heading  in nav.userHeading = heading }
        .onChange(of: tracker.userLocation) { _, location in updateNav(from: location) }
    }

    private func updateNav(from location: CLLocation?) {
        guard let coord = location?.coordinate else { return }
        nav.bearing  = bearing(from: coord, to: destination.coordinate)
        nav.distance = distance(from: coord, to: destination.coordinate)
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
// MARK: - Status Label
// ─────────────────────────────────────────────

private struct StatusLabel: View {
    let hasArrived: Bool
    let isOnTrack:  Bool

    private var title: String {
        if hasArrived { return "ARRIVED!" }
        return isOnTrack ? "ON TRACK" : "WRONG WAY"
    }

    private var subtitle: String {
        if hasArrived { return "You have reached your destination" }
        return isOnTrack ? "Continue toward your destination"
                         : "Head back toward the route"
    }

    private var titleColor: Color {
        if hasArrived { return .yellow }
        return isOnTrack ? .green : .red
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(titleColor)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.65))
        }
    }
}


// ─────────────────────────────────────────────
// MARK: - Compass View
// ─────────────────────────────────────────────

fileprivate struct CompassView: View {
    let nav: NavState

    var body: some View {
        GeometryReader { geo in
            let radius = (geo.size.width / 2) * 0.9
            ZStack {
                DirectionCone(nav: nav, radius: radius)
                CompassRing(userHeading: nav.userHeading, radius: radius, ringColor: ringColor)
                DestinationPin(nav: nav, radius: radius)
                    .rotationEffect(.degrees(-nav.userHeading))
                UserDot()
            }
            .frame(width: geo.size.width, height: geo.size.width)
        }
        .aspectRatio(1, contentMode: .fit) // selalu persegi, tanpa UIScreen
    }

    private var ringColor: Color {
        if nav.hasArrived { return .yellow }
        if nav.isOnTrack  { return .green  }
        return .white.opacity(0.25)
    }
}


// ─────────────────────────────────────────────
// MARK: - Compass Sub-views
// ─────────────────────────────────────────────

/// Kipas/sektor yang menunjukkan arah tujuan.
private struct DirectionCone: View {
    let nav:    NavState
    let radius: CGFloat

    var body: some View {
        ConeSectorShape(halfAngle: Nav.onTrackTolerance)
            .fill(coneGradient)
            .frame(width: radius * 2, height: radius * 2)
    }

    private var coneGradient: LinearGradient {
        let topColor: Color = nav.hasArrived ? .yellow
                            : nav.isOnTrack  ? .green
                            : .white
        let opacity: Double = nav.hasArrived || nav.isOnTrack ? 0.8 : 0.35
        return LinearGradient(
            colors: [topColor.opacity(opacity), topColor.opacity(0.05)],
            startPoint: .top,
            endPoint: .center
        )
    }
}

/// Lingkaran kompas dengan label N/E/S/W yang berputar sesuai arah user.
private struct CompassRing: View {
    let userHeading: Double
    let radius:      CGFloat
    let ringColor:   Color

    private let cardinals = [("N", 0.0), ("E", 90.0), ("S", 180.0), ("W", 270.0)]

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor, lineWidth: 1.5)
                .frame(width: radius * 2, height: radius * 2)

            // Titik-titik kecil di sekeliling lingkaran
            ForEach(0..<36, id: \.self) { i in
                if i % 9 != 0 {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: i % 3 == 0 ? 3 : 2,
                               height: i % 3 == 0 ? 3 : 2)
                        .offset(y: -(radius + 8))
                        .rotationEffect(.degrees(Double(i) * 10))
                }
            }

            // Panah dan label arah mata angin
            ForEach(cardinals, id: \.0) { label, angle in
                let isNorth = label == "N"
                ArrowTriangle()
                    .fill(isNorth ? Color.white : Color.white.opacity(0.45))
                    .frame(width: 7, height: 8)
                    .offset(y: -(radius + 20))
                    .rotationEffect(.degrees(angle))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isNorth ? .white : .white.opacity(0.6))
                    .offset(y: -(radius + 36))
                    .rotationEffect(.degrees(angle))
            }
        }
        .rotationEffect(.degrees(-userHeading))
    }
}

/// Pin yang menunjuk ke tujuan; posisinya bergeser sesuai bearing & jarak.
private struct DestinationPin: View {
    let nav:    NavState
    let radius: CGFloat

    private var offset: CGSize {
        let angleRad  = nav.bearing * .pi / 180
        let ratio     = CGFloat(min(nav.distance, Nav.pinMaxDistance) / Nav.pinMaxDistance)
        let minRadius = radius * Nav.pinMinRatio
        let r         = minRadius + ratio * (radius - minRadius)
        return CGSize(
            width:   CGFloat(sin(angleRad)) * r,
            height: -CGFloat(cos(angleRad)) * r
        )
    }

    var body: some View {
        Group {
            if nav.hasArrived {
                CirclePin(borderColor: .yellow) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.yellow)
                }
            } else if nav.isOnTrack {
                CirclePin(borderColor: .blue) {
                    Image(systemName: "mappin")
                        .font(.system(size: 18))
                        .foregroundColor(.red)
                }
            } else {
                // Hanya titik biru kecil saat salah arah
                Circle()
                    .fill(Color.blue)
                    .frame(width: 14, height: 14)
                    .shadow(color: .blue.opacity(0.6), radius: 4)
            }
        }
        .offset(offset)
    }
}

/// Titik putih kecil di tengah = posisi user.
private struct UserDot: View {
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 6, height: 6)
    }
}

/// Pin berbentuk lingkaran dengan border berwarna, isi bisa dikustomisasi.
private struct CirclePin<Content: View>: View {
    let borderColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Circle().fill(.black).frame(width: 36, height: 36)
            Circle().stroke(borderColor, lineWidth: 2).frame(width: 36, height: 36)
            content()
        }
    }
}


// ─────────────────────────────────────────────
// MARK: - Shapes
// ─────────────────────────────────────────────

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
// MARK: - Bottom Card
// ─────────────────────────────────────────────

struct BottomCard: View {
    let name:     String
    let distance: Double
    var onEnd:    () -> Void

    private var distanceLabel: String {
        guard distance > 0 else { return "Calculating..." }
        return distance >= 1000
            ? String(format: "%.1f km", distance / 1000)
            : "\(Int(distance)) m"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text(distanceLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
            }
            Spacer()
            Button("End Navigation", action: onEnd)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.blue)
                .clipShape(Capsule())
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}


// ─────────────────────────────────────────────
// MARK: - Preview
// ─────────────────────────────────────────────

#Preview {
    CompassNavigationView(
        destination: Location(
            name:       "Saved Point 1",
            coordinate: .init(latitude: -6.292363, longitude: 106.644227),
            altitude:   100,
            emoji:      "📍"
        ),
        onEndNavigation: {}
    )
}
