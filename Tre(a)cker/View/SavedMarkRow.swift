import SwiftUI
import CoreLocation

struct SavedMarkRow: View {
    let location: Location
    @Binding var locations: [Location]
    var userLocation: CLLocation?
    var onNavigate: () -> Void
    var onEdit: () -> Void

    private var distanceText: String {
        guard let user = userLocation else { return "—" }
        let point = CLLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        let meters = user.distance(from: point)
        if meters < 1000 {
            return "\(Int(meters)) m"
        } else {
            return String(format: "%.1f km", meters / 1000)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(location.emoji.isEmpty ? "📍" : location.emoji)
                .font(.system(size: 26))
                .frame(width: 48, height: 48)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    // Jarak ke user
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                        Text(distanceText)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.gray)

                    Text("·")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.4))

                    // Altitude
                    HStack(spacing: 3) {
                        Image(systemName: "mountain.2.fill")
                            .font(.system(size: 10))
                        Text("\(Int(location.altitude)) mdpl")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.gray)
                }
            }

            Spacer()

            Button(action: onNavigate) {
                Image(systemName: "location.circle")
                    .font(.system(size: 28))
                    .foregroundColor(Color(red: 0.2, green: 0.5, blue: 1.0))
            }
            .buttonStyle(.plain)

            Button(action: onEdit) {
                Text("Edit")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.leading, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
