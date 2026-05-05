import SwiftUI
import CoreLocation

struct ModifyPin: View {
    @Environment(\.dismiss) var dismiss

    let location: Location
    var onSave: (Location) -> Void
    var onDelete: () -> Void

    @State private var name: String
    @State private var emoji: String
    @State private var notes: String = ""
    @FocusState private var isEmojiFieldFocused: Bool

    init(location: Location, onSave: @escaping (Location) -> Void, onDelete: @escaping () -> Void) {
        self.location = location
        self.onSave   = onSave
        self.onDelete = onDelete
        _name  = State(initialValue: location.name)
        _emoji = State(initialValue: location.emoji)
    }

    var body: some View {
        Form {
            // Name + Emoji
            Section {
                HStack(spacing: 12) {
                    TextField("Location name", text: $name)
                    Button {
                        isEmojiFieldFocused = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 44, height: 44)
                            Text(emoji.isEmpty ? "📍" : emoji)
                                .font(.title3)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 6)
                .overlay {
                    TextField("", text: $emoji)
                        .focused($isEmojiFieldFocused)
                        .opacity(0)
                        .allowsHitTesting(false)
                }
            }

            // Notes
            Section {
                TextField("Add a note", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            // Details (read-only)
            Section {
                VStack(spacing: 16) {
                    detailRow(label: "Altitude", value: "\(Int(location.altitude)) m")
                    Divider()
                    detailRow(
                        label: "Coordinates",
                        value: String(format: "%.4f, %.4f",
                                     location.coordinate.latitude,
                                     location.coordinate.longitude)
                    )
                    Divider()
                    detailRow(label: "Saved", value: formattedDateTime(location.timestamp))
                }
                .padding(.vertical, 4)
            }

            // Delete
            Section {
                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Label("Delete Location", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Edit Pin")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)  // biarkan default chevron
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("", systemImage: "checkmark") {
                    let updated = Location(
                        id:         location.id,
                        name:       name,
                        coordinate: location.coordinate,
                        timestamp:  location.timestamp,
                        altitude:   location.altitude,
                        emoji:      emoji
                    )
                    onSave(updated)
                    dismiss()
                }
                .disabled(name.isEmpty)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing).foregroundColor(.secondary)
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
