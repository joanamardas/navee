// ModifyPin.swift

import SwiftUI
import CoreLocation

struct ModifyPin: View {
    @Environment(\.dismiss) var dismiss

    @Binding var location: Location
    var userLocation: CLLocation?
    var onDelete: () -> Void

    private let iconOptions = [
        "mappin", "tent.fill", "sun.max.fill", "water.waves",
        "flag.fill", "mountain.2.fill", "flame.fill", "binoculars.fill"
    ]

    // Sama persis dengan mapping di SavedMarksView
    private func iconColor(for icon: String) -> Color {
        switch icon {
        case "mappin":         return Color(red: 0.25, green: 0.55, blue: 1.0)
        case "tent.fill":      return Color(red: 0.22, green: 0.65, blue: 0.38)
        case "sun.max.fill":   return Color(red: 1.0,  green: 0.72, blue: 0.10)
        case "water.waves":    return Color(red: 0.12, green: 0.68, blue: 0.90)
        case "flag.fill":      return Color(red: 1.0,  green: 0.30, blue: 0.22)
        case "mountain.2.fill":return Color(red: 0.50, green: 0.42, blue: 0.36)
        case "flame.fill":     return Color(red: 1.0,  green: 0.42, blue: 0.12)
        case "binoculars.fill":return Color(red: 0.40, green: 0.32, blue: 0.80)
        default:               return Color(red: 0.25, green: 0.55, blue: 1.0)
        }
    }

    private var distanceToPin: Double? {
        guard let userLoc = userLocation else { return nil }
        let pinLoc = CLLocation(latitude: location.coordinate.latitude,
                                longitude: location.coordinate.longitude)
        return userLoc.distance(from: pinLoc)
    }

    var body: some View {
        Form {

            // MARK: Nama Pin
            Section {
                TextField("Point name", text: $location.name)
            }

            // MARK: Pilih Icon
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(iconOptions, id: \.self) { icon in
                            let isSelected = location.emoji == icon
                            let color = iconColor(for: icon)

                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                                    location.emoji = icon
                                }
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(isSelected ? color : Color.white.opacity(0.07))
                                        .frame(width: 44, height: 44)

                                    // Ring border saat selected
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(color.opacity(0.5), lineWidth: 1.5)
                                            .frame(width: 44, height: 44)
                                    }

                                    Image(systemName: icon)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(isSelected ? .white : .secondary)
                                }
                                // Scale up saat selected
                                .scaleEffect(isSelected ? 1.08 : 1.0)
                            }
                            .buttonStyle(.plain)
                            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isSelected)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
            }

            // MARK: Catatan
            Section {
                TextField("Add a note", text: $location.notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            // MARK: Info (read-only)
            Section {
                if let dist = distanceToPin {
                    InfoRow(label: "Distance",
                            value: dist < 1000 ? "\(Int(dist)) m away"
                                               : String(format: "%.1f km away", dist / 1000))
                }
                InfoRow(label: "Altitude",    value: "\(Int(location.altitude)) mdpl")
                InfoRow(label: "Coordinates", value: String(format: "%.4f, %.4f",
                                                            location.coordinate.latitude,
                                                            location.coordinate.longitude))
                InfoRow(label: "Saved",       value: formattedDate(location.timestamp))
            }

            // MARK: Hapus
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

    private func formattedDate(_ date: Date) -> String {
        let cal = Calendar.current
        let timeFormatter = DateFormatter(); timeFormatter.timeStyle = .short
        if cal.isDateInToday(date)     { return "Today, \(timeFormatter.string(from: date))" }
        if cal.isDateInYesterday(date) { return "Yesterday, \(timeFormatter.string(from: date))" }
        let dateFormatter = DateFormatter(); dateFormatter.dateStyle = .medium
        return "\(dateFormatter.string(from: date)), \(timeFormatter.string(from: date))"
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing).foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ModifyPin(
            location: .constant(Location(
                name: "Point 1",
                coordinate: .init(latitude: -6.2, longitude: 106.8166),
                altitude: 12,
                emoji: "flame.fill",
                notes: ""
            )),
            userLocation: CLLocation(latitude: -6.2012, longitude: 106.8154),
            onDelete: {}
        )
    }
    .preferredColorScheme(.dark)
}
