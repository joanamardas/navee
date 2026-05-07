//
//  DummyLocations.swift
//  Navee
//
//  Created by Rosamond Patricia Selamat Lie on 07/05/26.
//

import Foundation
import CoreLocation

enum DummyLocations {

    static let demoPin = Location(
        name: "Camping Area",
        coordinate: CLLocationCoordinate2D(
            latitude: -6.301300854733375,
            longitude: 106.65339086942133
        ),
        altitude: 39,
        emoji: "tent.fill",
        notes: "Best sunrise spot"
    )
}
