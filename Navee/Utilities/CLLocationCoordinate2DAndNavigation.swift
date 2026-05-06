//
//  CLLocationCoordinate2DAndNavigation.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import CoreLocation

extension CLLocationCoordinate2D {

    /// Bearing (arah kompas) dari titik ini ke `destination`, dalam derajat 0–360.
    func bearing(to destination: CLLocationCoordinate2D) -> Double {
        let lat1 = latitude               * .pi / 180
        let lat2 = destination.latitude   * .pi / 180
        let dLon = (destination.longitude - longitude) * .pi / 180
        let y    = sin(dLon) * cos(lat2)
        let x    = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Jarak (meter) dari titik ini ke `destination`.
    func distance(to destination: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: destination.latitude,
                                       longitude: destination.longitude))
    }
}
