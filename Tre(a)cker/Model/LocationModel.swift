import Foundation
import CoreLocation

struct Location: Identifiable, Hashable, Equatable {
    let id: UUID
    var name: String
    var coordinate: CLLocationCoordinate2D
    var timestamp: Date
    var altitude: Double
    var notes: String
    var emoji: String

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

    // Hashable & Equatable manual karena CLLocationCoordinate2D tidak conform
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Location, rhs: Location) -> Bool {
        lhs.id == rhs.id
    }
}
