// MainView.swift
// Layar utama: berisi peta, tombol add mark, dan overlay start trekking.

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Konstanta

private enum MapConfig {
    static let defaultCenter = CLLocationCoordinate2D(latitude: -6.715290, longitude: 106.733032)
    static let defaultSpan: Double   = 1_300
    static let nearbyThreshold: Double = 10
}

// MARK: - Icon/Color helper (mirrors SavedMarkRow, ModifyPin, CompassNavigationView)

private func pinIconColor(for emoji: String) -> (top: Color, bottom: Color) {
    switch emoji {
    case "mappin":
        return (Color(red: 0.25, green: 0.55, blue: 1.0), Color(red: 0.08, green: 0.28, blue: 0.86))
    case "tent.fill":
        return (Color(red: 0.22, green: 0.65, blue: 0.38), Color(red: 0.10, green: 0.42, blue: 0.22))
    case "sun.max.fill":
        return (Color(red: 1.0,  green: 0.72, blue: 0.10), Color(red: 0.88, green: 0.50, blue: 0.04))
    case "water.waves":
        return (Color(red: 0.12, green: 0.68, blue: 0.90), Color(red: 0.06, green: 0.44, blue: 0.72))
    case "flag.fill":
        return (Color(red: 1.0,  green: 0.30, blue: 0.22), Color(red: 0.80, green: 0.12, blue: 0.08))
    case "mountain.2.fill":
        return (Color(red: 0.50, green: 0.42, blue: 0.36), Color(red: 0.30, green: 0.24, blue: 0.18))
    case "flame.fill":
        return (Color(red: 1.0,  green: 0.42, blue: 0.12), Color(red: 0.88, green: 0.22, blue: 0.04))
    case "binoculars.fill":
        return (Color(red: 0.40, green: 0.32, blue: 0.80), Color(red: 0.22, green: 0.14, blue: 0.60))
    default:
        return (Color(red: 0.25, green: 0.55, blue: 1.0), Color(red: 0.08, green: 0.28, blue: 0.86))
    }
}

private func pinIconName(for emoji: String) -> String {
    emoji.isEmpty ? "mappin" : emoji
}

// MARK: - MainView

struct MainView: View {

    @State private var mapPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: MapConfig.defaultCenter,
            latitudinalMeters: MapConfig.defaultSpan,
            longitudinalMeters: MapConfig.defaultSpan
        )
    )

    @StateObject private var tracker = LocationTracker()

    @State private var locations: [Location] = []
    @State private var routeLine: [CLLocationCoordinate2D] = []

    @State private var isTracking = false
    @State private var showSavedMarks = false
    @State private var selectedPinID: Location.ID? = nil
    @State private var compassDestinationIndex: Int? = nil

    var body: some View {
        ZStack {
            mapLayer

            if isTracking {
                TrackingToolbar(
                    pinCount: locations.count,
                    onShowMarks: { showSavedMarks = true },
                    onAddMark: addMark
                )
            }

            if !isTracking {
                StartOverlay { isTracking = true }
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.18)) { selectedPinID = nil }
        }
        .fullScreenCover(isPresented: Binding(
            get: { compassDestinationIndex != nil },
            set: { if !$0 { compassDestinationIndex = nil } }
        )) {
            if let idx = compassDestinationIndex {
                CompassNavigationView(
                    allLocations:     locations,
                    destinationIndex: idx,
                    onEndNavigation:  { compassDestinationIndex = nil }
                )
            }
        }
        .sheet(isPresented: $showSavedMarks) { [locations] in
            SavedMarksView(
                locations: $locations,
                isPresented: $showSavedMarks,
                onNavigate: { location in
                    showSavedMarks = false
                    if let idx = locations.firstIndex(where: { $0.id == location.id }) {
                        compassDestinationIndex = idx
                    }
                },
                userLocation: tracker.userLocation
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.black)
        }
    }

    // MARK: - Map Layer

    private var mapLayer: some View {
        Map(position: $mapPosition) {
            if let userCoord = tracker.userLocation?.coordinate {
                Annotation("", coordinate: userCoord, anchor: .center) {
                    FootstepMarker()
                }
            }

            ForEach(locations) { location in
                Annotation("", coordinate: location.coordinate, anchor: .bottom) {
                    DynamicTearDropPin(
                        location: location,
                        isSelected: selectedPinID == location.id,
                        onTap: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                selectedPinID = (selectedPinID == location.id) ? nil : location.id
                            }
                        },
                        onNavigate: {
                            selectedPinID = nil
                            openCompass(to: location)
                        }
                    )
                }
            }

            if !routeLine.isEmpty {
                MapPolyline(coordinates: routeLine)
                    .stroke(.blue, lineWidth: 4)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .preferredColorScheme(.dark)
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapPitchToggle()
            MapScaleView()
        }
        .onAppear {
            tracker.startTracking()
            centerMapOnUser()
        }
        .blur(radius: isTracking ? 0 : 10)
        .allowsHitTesting(isTracking)
    }

    // MARK: - Actions

    private func centerMapOnUser() {
        Task {
            for try await update in CLLocationUpdate.liveUpdates() {
                guard let coord = update.location?.coordinate else { continue }
                await MainActor.run {
                    withAnimation(.easeInOut) {
                        mapPosition = .region(MKCoordinateRegion(
                            center: coord,
                            latitudinalMeters: MapConfig.defaultSpan,
                            longitudinalMeters: MapConfig.defaultSpan
                        ))
                    }
                }
                break
            }
        }
    }

    private func addMark() {
        guard let location = tracker.currentLocation() else {
            print("[AddMark] Lokasi belum tersedia")
            return
        }
        let pin = Location(
            name:       "PIN\(locations.count + 1)",
            coordinate: location.coordinate,
            altitude:   location.altitude,
            emoji:      "mappin",
            notes:      ""
        )
        locations.append(pin)
    }

    private func openCompass(to destination: Location) {
        guard let idx = locations.firstIndex(where: { $0.id == destination.id }) else { return }
        compassDestinationIndex = idx
    }

    private func drawRoute(to destination: Location) {
        Task {
            for try await update in CLLocationUpdate.liveUpdates() {
                guard let userCoord = update.location?.coordinate else { continue }
                await MainActor.run {
                    let remaining = locations.filter { !isNear(userCoord, $0.coordinate) }
                    guard let destIndex = remaining.firstIndex(where: { $0.id == destination.id })
                    else { routeLine = []; return }
                    let waypoints = remaining[(destIndex + 1)...]
                        .sorted { $0.timestamp > $1.timestamp }
                    var route: [CLLocationCoordinate2D] = [userCoord]
                    waypoints.forEach { route.append($0.coordinate) }
                    route.append(destination.coordinate)
                    routeLine = route
                }
                break
            }
        }
    }

    private func isNear(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            < MapConfig.nearbyThreshold
    }
}

// MARK: - Footstep Marker

private struct FootstepMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.18))
                .frame(width: 44, height: 44)
            Circle()
                .fill(Color.white)
                .frame(width: 30, height: 30)
            Image(systemName: "figure.walk")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.blue)
        }
    }
}

// MARK: - Dynamic Teardrop Pin
// Warna kepala pin mengikuti emoji/icon yang dipilih user — sama dengan SavedMarkRow.

private struct DynamicTearDropPin: View {
    let location: Location
    let isSelected: Bool
    let onTap: () -> Void
    let onNavigate: () -> Void

    private var iconName: String { pinIconName(for: location.emoji) }
    private var colors: (top: Color, bottom: Color) { pinIconColor(for: location.emoji) }

    var body: some View {
        ZStack(alignment: .bottom) {

            if isSelected {
                CalloutBubble(
                    name: location.name,
                    accentColor: colors.top,
                    onNavigate: onNavigate
                )
                .offset(y: -60)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8, anchor: .bottom).combined(with: .opacity),
                    removal:   .scale(scale: 0.8, anchor: .bottom).combined(with: .opacity)
                ))
                .zIndex(10)
            }

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [colors.top, colors.bottom],
                                startPoint: .top,
                                endPoint:   .bottom
                            )
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: iconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }

                PinTail()
                    .fill(colors.bottom)
                    .frame(width: 12, height: 10)
                    .offset(y: -1)
            }
            .scaleEffect(isSelected ? 1.12 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isSelected)
            .onTapGesture { onTap() }
        }
    }
}

// MARK: - Pin Tail Shape

private struct PinTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Callout Bubble
// Tombol Navigate pakai warna aksen dari pin masing-masing.

private struct CalloutBubble: View {
    let name: String
    let accentColor: Color
    let onNavigate: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Button(action: onNavigate) {
                HStack(spacing: 6) {
                    Text("Navigate")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(accentColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(accentColor, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.14).opacity(0.96))
        )
        .overlay(alignment: .bottom) {
            Triangle()
                .fill(Color(red: 0.12, green: 0.12, blue: 0.14).opacity(0.96))
                .frame(width: 12, height: 7)
                .offset(y: 6)
        }
        .fixedSize()
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Tracking Toolbar

private struct TrackingToolbar: View {
    let pinCount: Int
    let onShowMarks: () -> Void
    let onAddMark: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 14) {

                ZStack(alignment: .topTrailing) {
                    Button(action: onShowMarks) {
                        ZStack {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 64, height: 64)
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.28), .clear],
                                        startPoint: .top,
                                        endPoint:   .center
                                    )
                                )
                                .frame(width: 64, height: 64)
                            Image(systemName: "flag.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(GlassButtonStyle())

                    if pinCount > 0 {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.18, green: 0.78, blue: 0.35))
                                .frame(width: 24, height: 24)
                            Text("\(min(pinCount, 99))")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .offset(x: 4, y: -4)
                    }
                }

                Button(action: onAddMark) {
                    ZStack {
                        Capsule()
                            .fill(Color(red: 0.18, green: 0.45, blue: 1.0))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.22), .clear],
                                    startPoint: .top,
                                    endPoint:   .center
                                )
                            )
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
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
    }
}

private struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Start Overlay

private struct StartOverlay: View {
    let onStart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.1)
            VStack(spacing: 20) {
                Text("Are you ready to start?")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Button(action: onStart) {
                    Label("Start Trekking", systemImage: "location.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 32)
                        .background(Color.white)
                        .cornerRadius(50)
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Preview

#Preview { MainView() }
