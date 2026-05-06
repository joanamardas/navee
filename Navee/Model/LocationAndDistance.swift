//
//  LocationAndDistance.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import CoreLocation

extension Location {

    /// Jarak dari lokasi user ke pin ini.
    /// - Returns: `nil` jika `userLocation` tidak tersedia.
    func distance(from userLocation: CLLocation?) -> Double? {
        guard let userLoc = userLocation else { return nil }
        let pinLoc = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        return userLoc.distance(from: pinLoc)
    }

    /// String jarak yang diformat otomatis.
    /// - Parameters:
    ///   - userLocation: Lokasi user saat ini.
    ///   - suffix: Teks tambahan setelah angka (mis. "away"). Default kosong.
    ///   - fallback: Teks jika lokasi user tidak tersedia. Default "—".
    func formattedDistance(
        from userLocation: CLLocation?,
        suffix: String = "",
        fallback: String = "—"
    ) -> String {
        guard let meters = distance(from: userLocation) else { return fallback }
        let trail = suffix.isEmpty ? "" : " \(suffix)"
        return meters < 1_000
            ? "\(Int(meters)) m\(trail)"
            : String(format: "%.1f km\(trail)", meters / 1_000)
    }
}
