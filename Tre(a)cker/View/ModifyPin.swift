import SwiftUI
import CoreLocation

struct ModifyPin: View {
    @Environment(\.dismiss) var dismiss

    @Binding var location: Location
    var userLocation: CLLocation?
    var onDelete: () -> Void

    private let iconOptions: [String] = [
        "mappin",
        "tent.fill",
        "sun.max.fill",
        "water.waves",
        "flag.fill",
        "mountain.2.fill",
        "flame.fill",
        "binoculars.fill"
    ]

    private var calculatedDistance: Double? {
        guard let userLoc = userLocation else { return nil }
        let pinLoc = CLLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        return userLoc.distance(from: pinLoc)
    }

    var body: some View {
        Form {

            // MARK: - Name
            Section {
                TextField("Point name", text: $location.name)
            }

            // MARK: - Icon picker
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button {
                                location.emoji = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(location.emoji == icon ? .blue : .secondary)
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // MARK: - Notes
            Section {
                TextField("Add a note", text: $location.notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            // MARK: - Details (read-only)
            Section {
                if let dist = calculatedDistance {
                    detailRow(
                        label: "Distance",
                        value: dist < 1000
                            ? "\(Int(dist)) m away"
                            : String(format: "%.1f km away", dist / 1000)
                    )
                }
                detailRow(
                    label: "Altitude",
                    value: "\(Int(location.altitude)) mdpl"
                )
                detailRow(
                    label: "Coordinates",
                    value: String(
                        format: "%.4f, %.4f",
                        location.coordinate.latitude,
                        location.coordinate.longitude
                    )
                )
                detailRow(
                    label: "Saved",
                    value: formattedDateTime(location.timestamp)
                )
            }

            // MARK: - Delete
            Section {
                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Text("Delete Location")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle("Edit Point")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                .disabled(location.name.isEmpty)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.secondary)
        }
    }

    private func formattedDateTime(_ date: Date) -> String {
        let cal = Calendar.current
        let tf  = DateFormatter(); tf.timeStyle = .short
        if cal.isDateInToday(date)     { return "Today, \(tf.string(from: date))" }
        if cal.isDateInYesterday(date) { return "Yesterday, \(tf.string(from: date))" }
        let df = DateFormatter(); df.dateStyle = .medium
        return "\(df.string(from: date)), \(tf.string(from: date))"
    }
}

#Preview {
    NavigationStack {
        ModifyPin(
            location: .constant(
                Location(
                    name: "Point 1",
                    coordinate: .init(latitude: -6.2, longitude: 106.8166),
                    altitude: 12,
                    emoji: "mappin",
                    notes: ""
                )
            ),
            userLocation: CLLocation(latitude: -6.2012, longitude: 106.8154),
            onDelete: {}
        )
    }
    .preferredColorScheme(.dark)
}
