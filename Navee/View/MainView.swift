import SwiftUI
import MapKit
import CoreLocation

struct MainView: View {

    @Environment(\.dismiss) private var dismiss
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
        .sheet(isPresented: .constant(selectedPinID != nil)) {
            NavigationStack {
                if let selectedID = selectedPinID,
                   let selectedLocation = locations.first(where: { $0.id == selectedID }) {
                    BottomPinDetailView(
                        location: selectedLocation,
                        userLocation: tracker.userLocation,
                        onNavigate: {
                            openCompass(to: selectedLocation)
                        }
                    )
                    .presentationDetents([.fraction(0.3)])
                    .toolbarVisibility(.visible, for: .navigationBar)
                    .toolbar {
                        Button("back", systemImage: "xmark") {
                            dismiss()
                            selectedPinID = nil
                            
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: selectedPinID)
        .simultaneousGesture(
            TapGesture().onEnded {
                if selectedPinID != nil {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedPinID = nil
                    }
                }
            }
        )
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
                onSelect: handleSelect,
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
                        .allowsHitTesting(false)
                }
            }

            ForEach(locations) { location in
                Annotation("", coordinate: location.coordinate, anchor: .bottom) {
                    DynamicTearDropPin(
                        location: location,
                        isSelected: selectedPinID == location.id,
                        onTap: { toggleSelection(for: location.id) }
                    )
                    .zIndex(selectedPinID == location.id ? 1 : 0)
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

    private func handleSelect(_ location: Location) {
        showSavedMarks = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            selectedPinID = location.id
            withAnimation(.easeInOut(duration: 1)) {
                mapPosition = .region(MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: MapConfig.defaultSpan,
                    longitudinalMeters: MapConfig.defaultSpan
                ))
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
        withAnimation {
            selectedPinID = nil
        }
        guard let idx = locations.firstIndex(where: { $0.id == destination.id }) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            compassDestinationIndex = idx
        }
    }

    private func isNear(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            < MapConfig.nearbyThreshold
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
