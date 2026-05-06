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

    @State private var locations: [Location] = []
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
        .fullScreenCover(isPresented: compassNavigationBinding) {
            if let idx = compassDestinationIndex {
                CompassNavigationView(
                    allLocations: locations,
                    destinationIndex: idx,
                    onEndNavigation: { compassDestinationIndex = nil }
                )
            }
        }
        .sheet(isPresented: $showSavedMarks) {
            SavedMarksView(
                locations: $locations,
                isPresented: $showSavedMarks,
                onNavigate: handleNavigate,
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
                        onTap: { toggleSelection(for: location.id) },
                        onNavigate: { openCompass(to: location) }
                    )
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
        .onAppear {
            tracker.startTracking()
            centerMapOnUser()
        }
        .blur(radius: isTracking ? 0 : 10)
        .allowsHitTesting(isTracking)
    }

    // MARK: - Computed Properties

    private var compassNavigationBinding: Binding<Bool> {
        Binding(
            get: { compassDestinationIndex != nil },
            set: { if !$0 { compassDestinationIndex = nil } }
        )
    }

    // MARK: - Actions

    private func toggleSelection(for id: Location.ID) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            selectedPinID = (selectedPinID == id) ? nil : id
        }
    }

    private func handleNavigate(_ location: Location) {
        showSavedMarks = false
        if let idx = locations.firstIndex(where: { $0.id == location.id }) {
            compassDestinationIndex = idx
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
            name:       "PIN\(locations.count + 1)",
            coordinate: location.coordinate,
            altitude:   location.altitude,
            emoji:      "mappin",
            notes:      ""
        )
        locations.append(pin)
    }

    private func openCompass(to destination: Location) {
        selectedPinID = nil
        guard let idx = locations.firstIndex(where: { $0.id == destination.id }) else { return }
        compassDestinationIndex = idx
    }

    private func isNear(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            < MapConfig.nearbyThreshold
    }
}

// MARK: - Preview

#Preview { MainView() }
