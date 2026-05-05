//
//  MainView.swift
//  Tre(a)cker
//

import SwiftUI
import MapKit
import CoreLocation


// ─────────────────────────────────────────────
// MARK: - Constants
// ─────────────────────────────────────────────

private enum MapConfig {
    static let defaultCenter    = CLLocationCoordinate2D(latitude: -6.715290, longitude: 106.733032)
    static let defaultSpan      = 1_300.0   // meter — lebar area awal peta
    static let nearbyThreshold  = 15.0      // meter — pin dianggap "sudah dilewati"
    static let pinNamePrefix    = "PIN"
    static let pinEmoji         = "📍"
}


// ─────────────────────────────────────────────
// MARK: - Main View
// ─────────────────────────────────────────────

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
    @State private var locations:               [Location]                  = []
    @State private var straightLineCoordinates: [CLLocationCoordinate2D]   = []

    // ── Navigation ──
    @State private var navigatingTo: Location?      // nil = tidak sedang navigasi

    // ── UI ──
    @State private var showSavedMarks = false

    // ─────────────────────────────────────────────

    var body: some View {
        ZStack {
            mapLayer
            overlayButtons
        }
        // Sheet: daftar pin tersimpan
        .sheet(isPresented: $showSavedMarks) {
            SavedMarksView(
                locations: $locations,
                onNavigate: { location in
                    showSavedMarks = false
                    startNavigation(to: location)
                },
                onDelete: { location in
                    locations.removeAll { $0.id == location.id }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.black)
        }
        // Full-screen: compass navigation
        .fullScreenCover(item: $navigatingTo) { destination in
            CompassNavigationView(
                destination: destination,
                onEndNavigation: { navigatingTo = nil }
            )
        }
        .onAppear(perform: requestLocationAndCenter)
    }


    // ─────────────────────────────────────────────
    // MARK: - Map Layer
    // ─────────────────────────────────────────────

    private var mapLayer: some View {
        Map(position: $mapPosition) {

            // Pin-pin yang tersimpan
            ForEach(locations) { location in
                Annotation(location.name, coordinate: location.coordinate, anchor: .center) {
                    PinAnnotationView(emoji: location.emoji)
                }
            }

            // Posisi user
            UserAnnotation()

            // Garis lurus ke tujuan
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

    // Tombol flag — buka daftar pin tersimpan
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

    // Tombol ADD MARK — simpan posisi user sekarang
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

    // Tombol navigate — langsung navigasi ke pin terakhir
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

    /// Minta izin lokasi dan pusatkan peta ke posisi user.
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

    /// Simpan posisi GPS user saat ini sebagai pin baru.
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
    
    
    /// Mulai navigasi ke tujuan: tampilkan garis di peta, lalu buka CompassView.
    private func startNavigation(to destination: Location) {
        drawRouteLine(to: destination)
        navigatingTo = destination
    }

    /// Gambar garis lurus dari user → waypoints → tujuan.
    /// Waypoints = pin-pin yang dibuat SETELAH tujuan (harus dilewati dulu sebelum sampai).
    private func drawRouteLine(to destination: Location) {
        Task {
            for try await update in CLLocationUpdate.liveUpdates() {
                guard let userCoord = update.location?.coordinate else { continue }

                await MainActor.run {
                    // Hapus pin yang sudah dekat (sudah dilewati user)
                    locations.removeAll { isNear(userCoord, $0.coordinate) }

                    // Kalau tujuan sudah tidak ada di list (sudah dilewati), bersihkan garis
                    guard let destIndex = locations.firstIndex(where: { $0.id == destination.id }) else {
                        straightLineCoordinates = []
                        return
                    }

                    // Waypoints = pin setelah tujuan, diurutkan dari yang terbaru (harus dilewati duluan)
                    // Contoh: pins = [P1, P2, P3, P4, P5], tujuan = P3
                    // → rute: user → P5 → P4 → P3
                    let waypoints = locations[(destIndex + 1)...]
                        .sorted { $0.timestamp > $1.timestamp }

                    straightLineCoordinates = [userCoord]
                        + waypoints.map(\.coordinate)
                        + [destination.coordinate]
                }
            }
        }
    }

    /// Cek apakah dua koordinat berdekatan (< threshold).
    private func isNear(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            < MapConfig.nearbyThreshold
    }
}


// ─────────────────────────────────────────────
// MARK: - Sub-views
// ─────────────────────────────────────────────

/// Tampilan pin di atas peta.
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

/// Tombol bulat dengan ikon SF Symbol.
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


// ─────────────────────────────────────────────
// MARK: - Preview
// ─────────────────────────────────────────────

#Preview {
    MainView()
}
