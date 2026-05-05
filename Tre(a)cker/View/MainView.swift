import SwiftUI
import MapKit
import CoreLocation

private enum MapConfig {
    static let defaultCenter    = CLLocationCoordinate2D(latitude: -6.715290, longitude: 106.733032)
    static let defaultSpan      = 1_300.0
    static let nearbyThreshold  = 15.0
    static let pinNamePrefix    = "PIN"
    static let pinEmoji         = "📍"
}

struct MainView: View {

    // ── Map ──
    @State private var mapPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: MapConfig.defaultCenter,
            latitudinalMeters:  MapConfig.defaultSpan,
            longitudinalMeters: MapConfig.defaultSpan
        )
    )

    // ── Data ──
    @StateObject private var tracker = LocationTracker()
    @State private var locations: [Location] = []

    // ── Route line ──
    @State private var straightLineCoordinates: [CLLocationCoordinate2D] = []
    @State private var routeTask: Task<Void, Never>? = nil

    // ── Navigation ──
    @State private var navigatingTo: Location?

    // ── UI ──
    @State private var showSavedMarks = false

    var body: some View {
        ZStack {
            mapLayer
            overlayButtons
        }
        .sheet(isPresented: $showSavedMarks) {
            SavedMarksView(
                locations: $locations,
                isPresented: $showSavedMarks,
                onNavigate: { location in
                    startNavigation(to: location)
                },
                userLocation: tracker.userLocation
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $navigatingTo) { destination in
            CompassNavigationView(
                destination: destination,
                onEndNavigation: { endNavigation() }
            )
        }
        .onAppear(perform: requestLocationAndCenter)
    }

    // ─────────────────────────────────────────────
    // MARK: - Map Layer
    // ─────────────────────────────────────────────

    private var mapLayer: some View {
        Map(position: $mapPosition) {
            ForEach(locations) { location in
                Annotation(location.name, coordinate: location.coordinate, anchor: .center) {
                    PinAnnotationView(emoji: location.emoji)
                }
            }
            UserAnnotation()
            if !straightLineCoordinates.isEmpty {
                MapPolyline(coordinates: straightLineCoordinates)
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
    }

    // ─────────────────────────────────────────────
    // MARK: - Overlay Buttons
    // ─────────────────────────────────────────────

    private var overlayButtons: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                savedMarksButton
                addMarkButton
                navigateButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
    }

    private var savedMarksButton: some View {
        ZStack(alignment: .topTrailing) {
            CircleIconButton(icon: "flag", color: .blue) {
                showSavedMarks.toggle()
            }
            if !locations.isEmpty {
                Text("\(locations.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.orange)
                    .clipShape(Circle())
                    .offset(x: 4, y: -4)
            }
        }
    }

    private var addMarkButton: some View {
        Button(action: addCurrentLocationPin) {
            Text("ADD MARK")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.orange)
                .cornerRadius(14)
        }
    }

    private var navigateButton: some View {
        CircleIconButton(icon: "location.fill", color: .blue) {
            if let last = locations.last {
                startNavigation(to: last)
            }
        }
    }

    // ─────────────────────────────────────────────
    // MARK: - Actions
    // ─────────────────────────────────────────────

    private func requestLocationAndCenter() {
        tracker.startTracking()
        if let coordinate = tracker.userLocation?.coordinate {
            mapPosition = .region(MKCoordinateRegion(
                center:             coordinate,
                latitudinalMeters:  MapConfig.defaultSpan,
                longitudinalMeters: MapConfig.defaultSpan
            ))
        }
    }

    private func addCurrentLocationPin() {
        guard let location = tracker.currentLocation() else {
            print("[AddMark] Lokasi belum tersedia")
            return
        }
        let newPin = Location(
            name:       MapConfig.pinNamePrefix + "\(locations.count + 1)",
            coordinate: location.coordinate,
            altitude:   location.altitude,
            emoji:      MapConfig.pinEmoji
        )
        locations.append(newPin)
    }

    private func startNavigation(to destination: Location) {
        routeTask?.cancel()
        drawRouteLine(to: destination)
        navigatingTo = destination
    }

    private func endNavigation() {
        routeTask?.cancel()
        routeTask = nil
        straightLineCoordinates = []
        navigatingTo = nil
    }

    private func drawRouteLine(to destination: Location) {
        routeTask = Task {
            do {
                for try await update in CLLocationUpdate.liveUpdates() {
                    if Task.isCancelled { break }
                    guard let userCoord = update.location?.coordinate else { continue }
                    await MainActor.run {
                        guard !Task.isCancelled else { return }
                        guard let destIndex = locations.firstIndex(where: { $0.id == destination.id }) else {
                            straightLineCoordinates = []
                            return
                        }
                        let waypoints = locations[(destIndex + 1)...]
                            .sorted { $0.timestamp > $1.timestamp }
                        straightLineCoordinates = [userCoord]
                            + waypoints.map(\.coordinate)
                            + [destination.coordinate]
                    }
                }
            } catch { }
        }
    }

    private func isNear(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            < MapConfig.nearbyThreshold
    }
}

// ─────────────────────────────────────────────
// MARK: - Sub-views
// ─────────────────────────────────────────────

private struct PinAnnotationView: View {
    let emoji: String
    var body: some View {
        Text(emoji)
            .font(.system(size: 20))
            .padding(8)
            .background(.black)
            .clipShape(Circle())
            .overlay(Circle().stroke(.blue, lineWidth: 1))
            .shadow(radius: 3)
    }
}

private struct CircleIconButton: View {
    let icon:   String
    let color:  Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(color)
                .clipShape(Circle())
        }
    }
}

#Preview {
    MainView()
}
