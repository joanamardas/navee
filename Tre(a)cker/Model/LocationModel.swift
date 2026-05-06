// LocationModel.swift
// Model utama yang merepresentasikan satu titik/pin yang disimpan user di peta.

import Foundation
import CoreLocation

struct Location: Identifiable, Hashable {

    // MARK: - Properties

    let id: UUID          // ID unik, otomatis dibuat
    var name: String      // Nama titik, bisa diedit user
    var coordinate: CLLocationCoordinate2D  // Koordinat GPS (lat & lon)
    var timestamp: Date   // Waktu pin dibuat
    var altitude: Double  // Ketinggian dalam meter
    var emoji: String     // Icon SF Symbol yang dipilih user
    var notes: String     // Catatan opsional dari user

    // MARK: - Init

    init(
        id: UUID = UUID(),
        name: String,
        coordinate: CLLocationCoordinate2D,
        timestamp: Date = Date(),
        altitude: Double,
        emoji: String,
        notes: String = ""
    ) {
        self.id         = id
        self.name       = name
        self.coordinate = coordinate
        self.timestamp  = timestamp
        self.altitude   = altitude
        self.emoji      = emoji
        self.notes      = notes
    }

    // MARK: - Hashable & Equatable
    // CLLocationCoordinate2D tidak otomatis conform, jadi kita pakai id saja.

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Location, rhs: Location) -> Bool {
        lhs.id == rhs.id
    }
}
