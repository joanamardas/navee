// LocationTracker.swift
// ObservableObject yang mengurus semua urusan GPS & kompas.
// View cukup @StateObject / @ObservedObject dari sini — tidak perlu sentuh CLLocationManager langsung.

import Foundation
import CoreLocation
import Combine

class LocationTracker: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: - Published State
    // Semua @Published otomatis memicu update UI saat nilainya berubah.

    @Published var userLocation: CLLocation?              // Posisi GPS terkini
    @Published var heading: Double = 0                    // Arah kompas (derajat, true north)
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // MARK: - Private

    private let manager = CLLocationManager()

    // Filter agar update tidak terlalu sering & boros baterai
    private enum Filter {
        static let maxAccuracy: Double   = 50  // Abaikan GPS jika akurasi > 50 m
        static let headingFilter: Double = 1   // Update kompas minimal tiap 1°
        static let distanceFilter: Double = 1  // Update GPS minimal tiap 1 m
    }

    // MARK: - Init

    override init() {
        super.init()
        manager.delegate        = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.headingFilter   = Filter.headingFilter
        manager.distanceFilter  = Filter.distanceFilter
        authorizationStatus     = manager.authorizationStatus
    }

    // MARK: - Public API

    /// Mulai tracking — minta izin dulu kalau belum ada.
    func startTracking() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization() // Izin → delegate akan panggil beginUpdates
        case .authorizedWhenInUse, .authorizedAlways:
            beginUpdates()
        default:
            break // Denied / restricted — tidak bisa berbuat apa-apa
        }
    }

    /// Hentikan semua sensor untuk hemat baterai.
    func stopTracking() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    /// Ambil posisi terkini (dari cache kalau GPS belum update).
    func currentLocation() -> CLLocation? {
        userLocation ?? manager.location
    }

    // MARK: - Private Helpers

    private func beginUpdates() {
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    // MARK: - CLLocationManagerDelegate

    /// Dipanggil saat status izin berubah (pertama buka app, atau user ubah di Settings).
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse ||
           authorizationStatus == .authorizedAlways {
            beginUpdates()
        }
    }

    /// Dipanggil saat data GPS baru masuk. Simpan hanya kalau akurasi cukup baik.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last,
              latest.horizontalAccuracy >= 0,                    // -1 = invalid
              latest.horizontalAccuracy <= Filter.maxAccuracy    // terlalu tidak akurat? skip
        else { return }
        userLocation = latest
    }

    /// Dipanggil saat kompas bergerak. Pakai trueHeading, fallback ke magneticHeading.
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return } // -1 = tidak valid
        heading = newHeading.trueHeading >= 0
            ? newHeading.trueHeading
            : newHeading.magneticHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[LocationTracker] GPS error: \(error.localizedDescription)")
    }
}
