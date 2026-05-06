//
//  CompassView.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import SwiftUI
import CoreLocation

// MARK: - CompassView

struct CompassView: View {
    let nav: NavState
    let destination: Location

    var body: some View {
        GeometryReader { geo in
            let size   = geo.size.width
            let radius = size / 2

            ZStack {
                DirectionCone(isOnTrack: nav.isOnTrack, radius: radius)
                CompassDial(userHeading: nav.userHeading, isOnTrack: nav.isOnTrack, radius: radius)
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

// MARK: - CompassDial

private struct CompassDial: View {
    let userHeading: Double
    let isOnTrack: Bool
    let radius: CGFloat

    private let cardinalLabels: [(text: String, deg: Double, major: Bool)] = [
        ("N",   0, true), ("NE",  45, false),
        ("E",  90, true), ("SE", 135, false),
        ("S", 180, true), ("SW", 225, false),
        ("W", 270, true), ("NW", 315, false)
    ]

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width  / 2
            let cy = size.height / 2
            let R  = min(cx, cy)

            let ring = Path(ellipseIn: CGRect(x: cx - R, y: cy - R, width: R * 2, height: R * 2))
            ctx.stroke(ring, with: .color(.white.opacity(0.08)), lineWidth: 1)

            for deg in stride(from: 0.0, to: 360.0, by: 2.0) {
                let isMajor  = deg.truncatingRemainder(dividingBy: 90)  == 0
                let isCard   = deg.truncatingRemainder(dividingBy: 45)  == 0 && !isMajor
                let isMedium = deg.truncatingRemainder(dividingBy: 10)  == 0 && !isCard && !isMajor

                let outer: CGFloat = R - 2
                let inner: CGFloat = isMajor ? R - 22 : isCard ? R - 16 : isMedium ? R - 11 : R - 7

                let rad  = (deg - userHeading - 90) * .pi / 180
                let cosV = CGFloat(Foundation.cos(rad))
                let sinV = CGFloat(Foundation.sin(rad))

                var tick = Path()
                tick.move(to:    CGPoint(x: cx + outer * cosV, y: cy + outer * sinV))
                tick.addLine(to: CGPoint(x: cx + inner * cosV, y: cy + inner * sinV))

                let width:   CGFloat = isMajor ? 2.5 : isCard ? 2.0 : isMedium ? 1.5 : 1.0
                let opacity: Double  = isMajor ? 1.0 : isCard ? 0.8 : isMedium ? 0.55 : 0.3
                let color: Color = (deg == 0 || !isOnTrack) ? .white : .green

                ctx.stroke(tick, with: .color(color.opacity(opacity)),
                           style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
        }
        .id(isOnTrack)
        .overlay(
            ZStack {
                ForEach(cardinalLabels, id: \.deg) { item in
                    let rad  = (item.deg - userHeading) * .pi / 180
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
                        .offset(x: CGFloat(sin(rad)) * dist, y: -CGFloat(cos(rad)) * dist)
                }
            }
        )
    }
}

// MARK: - NorthPointer

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

// MARK: - DirectionCone

private struct DirectionCone: View {
    let isOnTrack: Bool
    let radius: CGFloat

    var body: some View {
        ConeSectorShape(halfAngle: 30)
            .fill(coneGradient)
            .frame(width: radius * 2, height: radius * 2)
            .animation(.easeInOut(duration: 0.3), value: isOnTrack)
    }

    private var coneGradient: RadialGradient {
        let center: Color = isOnTrack ? .green.opacity(0.72) : .white.opacity(0.28)
        return RadialGradient(
            colors: [center, .clear],
            center: UnitPoint(x: 0.5, y: 1.0),
            startRadius: 0,
            endRadius: radius * 2.0
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

// MARK: - DestinationPin

private struct DestinationPin: View {
    let nav: NavState
    let radius: CGFloat
    let destination: Location

    private var pinOffset: CGSize {
        let angleRad = nav.bearing * .pi / 180
        let ratio    = CGFloat(min(nav.distance, Nav.pinMaxDistance) / Nav.pinMaxDistance)
        let minR     = radius * Nav.pinMinRatio
        let r        = minR + ratio * (radius - minR)
        return CGSize(width:  CGFloat(sin(angleRad)) * r,
                      height: -CGFloat(cos(angleRad)) * r)
    }

    var body: some View {
        let color    = PinIconHelper.topColor(for: destination.emoji)
        let iconName = PinIconHelper.iconName(for: destination.emoji)

        Group {
            if nav.isOnTrack || nav.hasArrived {
                TeardropPin(color: color, iconName: iconName)
            } else {
                Circle().fill(color.opacity(0.5)).frame(width: 10, height: 10)
            }
        }
        .offset(pinOffset)
    }
}

// MARK: - TeardropPin

private struct TeardropPin: View {
    let color: Color
    let iconName: String

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 34, height: 34)
                    .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
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

// MARK: - UserDot

private struct UserDot: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.12)).frame(width: 22, height: 22)
            Circle().fill(Color.white).frame(width: 13, height: 13)
            Circle().fill(Color.blue).frame(width: 8,  height: 8)
        }
    }
}
