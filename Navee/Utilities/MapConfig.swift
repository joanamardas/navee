//
//  MapConfig.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import CoreLocation

enum MapConfig {
    static let defaultCenter = CLLocationCoordinate2D(
        latitude: -6.715290,
        longitude: 106.733032
    )
    static let defaultSpan: Double = 1_300
    static let nearbyThreshold: Double = 10
}
