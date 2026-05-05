//
//  LocationTracker.swift
//  Tre(a)cker
//
//  Created by neena on 05/05/26.
//

import Foundation
import CoreLocation
import Combine


class LocationTracker: NSObject, ObservableObject, CLLocationManagerDelegate {

    // ── Published (dikonsumsi oleh CompassNavigationView) ──
    @Published var heading:             Double              = 0
    @Published var userLocation:        CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isHeadingAvailable:  Bool                = false

    private let manager = CLLocationManager()

    // ── Konstanta filter ──
    private enum Filter {
        static let maxAccuracy:   Double = 50   // meter — lokasi lebih buruk dari ini diabaikan
        static let headingFilter: Double = 1    // derajat — update kompas minimum
        static let distanceFilter: Double = 1  // meter — update GPS minimum
    }

    override init() {
        super.init()
        manager.delegate        = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.headingFilter   = Filter.headingFilter
        manager.distanceFilter  = Filter.distanceFilter

        authorizationStatus   = manager.authorizationStatus
        isHeadingAvailable    = CLLocationManager.headingAvailable()
    }


    // ─────────────────────────────────────────────
    // MARK: - Start / Stop
    // ─────────────────────────────────────────────

    func startTracking() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()     // izin diminta → beginUpdates dipanggil dari delegate
        case .authorizedWhenInUse, .authorizedAlways:
            beginUpdates()
        default:
            break                                       // denied / restricted — tidak bisa berbuat apa-apa
        }
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    private func beginUpdates() {
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }


    // ─────────────────────────────────────────────
    // MARK: - CLLocationManagerDelegate
    // ─────────────────────────────────────────────

    /// Dipanggil saat status izin lokasi berubah (pertama kali minta, atau user ubah di Settings).
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse ||
           authorizationStatus == .authorizedAlways {
            beginUpdates()
        }
    }

    /// Dipanggil saat GPS dapat data baru. Hanya simpan kalau akurasi cukup baik.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last,
              latest.horizontalAccuracy >= 0,          // -1 = invalid
              latest.horizontalAccuracy <= Filter.maxAccuracy else { return }
        userLocation = latest
    }

    /// Dipanggil saat kompas bergerak. Pakai trueHeading kalau valid, fallback ke magneticHeading.
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }   // -1 = tidak valid
        heading = newHeading.trueHeading >= 0
            ? newHeading.trueHeading
            : newHeading.magneticHeading
    }

    /// Dipanggil saat terjadi error GPS (misal: sinyal hilang, denied di tengah jalan).
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[LocationTracker] Error: \(error.localizedDescription)")
    }
    
    /// Simpan posisi GPS user saat ini sebagai pin baru.
    func currentLocation() -> CLLocation? {
        return userLocation ?? manager.location
    }
}
