//
//  LocationModel.swift
//  Tre(a)cker
//
//  Created by Rosamond Patricia Selamat Lie on 01/05/26.
//

import Foundation
import CoreLocation

struct Location: Identifiable{
    let id: UUID
    var name: String
    var coordinate: CLLocationCoordinate2D
    var timestamp: Date = Date()
    var altitude: Double
    var notes: String
    var emoji: String
    
    init (id: UUID = UUID(), name: String, coordinate : CLLocationCoordinate2D, timestamp: Date = Date(), altitude: Double, emoji: String, notes: String) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.timestamp = timestamp
        self.altitude = altitude
        self.emoji = emoji
        self.notes = notes
    }
}


