// ModifyPin.swift

import SwiftUI
import CoreLocation

struct ModifyPin: View {
    @Environment(\.dismiss) var dismiss

    @Binding var location: Location
    var userLocation: CLLocation?
    var onDelete: () -> Void

    var body: some View {
        Form {
            nameSection
            iconSection
            notesSection
            infoSection
            deleteSection
        }
        .navigationTitle("Edit Point")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                doneButton
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section {
            TextField("Point name", text: $location.name)
        }
    }

    private var iconSection: some View {
        Section {
            IconPicker(selectedIcon: $location.emoji)
        }
    }

    private var notesSection: some View {
        Section {
            TextField("Add a note", text: $location.notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var infoSection: some View {
        Section {
            InfoRow(
                label: "Distance",
                value: location.formattedDistance(from: userLocation, suffix: "away")
            )
            InfoRow(label: "Altitude",    value: "\(Int(location.altitude)) mdpl")
            InfoRow(label: "Coordinates", value: String(
                format: "%.4f, %.4f",
                location.coordinate.latitude,
                location.coordinate.longitude
            ))
            InfoRow(label: "Saved", value: location.timestamp.relativeFormatted())
        }
    }

    private var deleteSection: some View {
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

    private var doneButton: some View {
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
