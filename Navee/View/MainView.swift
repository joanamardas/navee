//
//  MainView.swift
//  Navee
//

import SwiftUI
import MapKit
import CoreLocation

struct MainView: View {

    @State private var mapPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: MapConfig.defaultCenter,
            latitudinalMeters: MapConfig.defaultSpan,
            longitudinalMeters: MapConfig.defaultSpan
        )
    )

    @StateObject private var tracker = LocationTracker()

//    @State private var locations:               [Location]        = []
    @State private var locations: [Location] = [
        DummyLocations.demoPin
    ]
    @State private var isTracking:              Bool              = false
    @State private var sheetContent:            MarkSheetContent? = nil
    @State private var compassDestinationIndex: Int?              = nil

    private let spring: Animation = .spring(response: 0.4, dampingFraction: 0.82)

    // Tinggi SmallDetent (240) + sedikit breathing room
    // supaya pin selected tidak ketutupan sheet
    private let detailSheetHeight: CGFloat = 260

    var body: some View {
        ZStack {
            mapLayer

            if isTracking {
                TrackingToolbar(
                    pinCount:    locations.count,
                    onShowMarks: { sheetContent = .list },
                    onAddMark:   addMark
                )
            }

            if !isTracking {
                StartOverlay { isTracking = true }
            }
        }
        .sheet(isPresented: sheetIsPresented) {
            UnifiedMarkSheet(
                locations:     $locations,
                content:       $sheetContent,
                userLocation:  tracker.userLocation,
                onNavigate:    handleNavigate,
                onSelectOnMap: handleSelectOnMap
            )
        }
        .fullScreenCover(isPresented: compassNavigationBinding) {
            if let idx = compassDestinationIndex {
                CompassNavigationView(
                    allLocations:     locations,
                    destinationIndex: idx,
                    onEndNavigation:  { compassDestinationIndex = nil }
                )
            }
        }
    }

    // MARK: - Map Layer

    private var mapLayer: some View {
        GeometryReader { geo in
            Map(position: $mapPosition) {
                if let userCoord = tracker.userLocation?.coordinate {
                    Annotation("", coordinate: userCoord, anchor: .center) {
                        FootstepMarker()
                            .allowsHitTesting(false)
                    }
                }

                ForEach(locations) { location in
                    Annotation("", coordinate: location.coordinate, anchor: .bottom) {
                        DynamicTearDropPin(
                            location:   location,
                            isSelected: isSelected(location),
                            onTap:      { handlePinTap(location) }
                        )
                        .zIndex(isSelected(location) ? 1 : 0)
                    }
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
            // FIX: geser map ke atas saat detail sheet muncul supaya pin
            // selected tidak tertutup sheet, seperti behavior Google Maps / Apple Maps.
            // Tidak ada overlay hitam — map tetap bersih dan interaktif.
            .safeAreaInset(edge: .bottom) {
                if isDetailVisible {
                    Color.clear.frame(height: detailSheetHeight)
                }
            }
            .onAppear {
                tracker.startTracking()
                centerMapOnUser()
            }
            .overlay {
                if !isTracking {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                }
            }
            .allowsHitTesting(isTracking)
        }
    }

    // MARK: - Computed Properties

    private var isDetailVisible: Bool {
        if case .detail = sheetContent { return true }
        return false
    }

    private var sheetIsPresented: Binding<Bool> {
        Binding(
            get: { sheetContent != nil },
            set: { if !$0 { sheetContent = nil } }
        )
    }

    private var compassNavigationBinding: Binding<Bool> {
        Binding(
            get: { compassDestinationIndex != nil },
            set: { if !$0 { compassDestinationIndex = nil } }
        )
    }

    private func isSelected(_ location: Location) -> Bool {
        if case .detail(let l) = sheetContent { return l.id == location.id }
        return false
    }

    // MARK: - Actions

    private func handlePinTap(_ location: Location) {
        if case .detail(let current) = sheetContent, current.id == location.id {
            sheetContent = nil
        } else {
            sheetContent = .detail(location)
            centerMap(on: location.coordinate)
        }
    }

    private func handleNavigate(_ location: Location) {
        sheetContent = nil
        if let idx = locations.firstIndex(where: { $0.id == location.id }) {
            compassDestinationIndex = idx
        }
    }

    private func handleSelectOnMap(_ location: Location) {
        centerMap(on: location.coordinate)
    }

    private func centerMap(on coord: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 0.6)) {
            mapPosition = .region(MKCoordinateRegion(
                center: coord,
                latitudinalMeters: MapConfig.defaultSpan,
                longitudinalMeters: MapConfig.defaultSpan
            ))
        }
    }

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
            name:       "Checkpoint \(locations.count + 1)",
            coordinate: location.coordinate,
            altitude:   location.altitude,
            emoji:      "mappin",
            notes:      ""
        )
        locations.append(pin)
    }
}

// MARK: - Corner Radius Helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview

#Preview { MainView() }
