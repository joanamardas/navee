import SwiftUI
internal import _LocationEssentials

struct ModifyPin: View {
    @Environment(\.dismiss) var dismiss
    
    @Binding var location: Location
    var userLocation: CLLocation? // untuk hitung jarak asli
    var onDelete: () -> Void
    
    @FocusState private var isEmojiFieldFocused: Bool
    
    private var calculatedDistance: Double? {
            guard let userLoc = userLocation else { return nil }
            let pinLoc = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            return userLoc.distance(from: pinLoc)
        }
    
    var body: some View {
        
        Form {
            
            // MARK: - Editable: Name
            Section {
                HStack(spacing: 12) {
                    TextField("Location name", text: $location.name)
                    
                    Button {
                        isEmojiFieldFocused = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 44, height: 44)
                            
                            Text(location.emoji)
                                .font(.title3)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 6)
                .overlay {
                    TextField("", text: $location.emoji)
                        .focused($isEmojiFieldFocused)
                        .opacity(0)
                        .allowsHitTesting(false)
                }
            }
            
            // MARK: - Editable: Notes
            Section {
                TextField("Add a note", text: $location.notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            // MARK: - Read Only: Details
            VStack(spacing: 16) {
                
                //header: Text("Details"))
                // Distance
                detailRow(
                    label: "Distance",
                    value: "\(Int(calculatedDistance ?? 0)) m away"
                )
                
                Divider()
                
                // Coordinates
                detailRow(
                    label: "Coordinates",
                    value: "\(location.coordinate.latitude, default: "%.4f"), \(location.coordinate.longitude, default: "%.4f")"
                )
                
                Divider()
                
                // DateTime
                detailRow(
                    label: "Saved",
                    value: formattedDateTime(Date())
                )
            }
            .padding(.vertical, 4)
            
            
            // MARK: - Delete
            Section {
                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Label("Delete Location", systemImage: "trash")
                }
            }
            .foregroundStyle(Color(.systemRed))
        }
        .navigationTitle("Edit Pin")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if #available(iOS 26.0, *) {
                    Button(role: .close) {
                        dismiss()
                    }
                } else {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if #available(iOS 26.0, *) {
                    Button(role: .confirm) {
                        dismiss()
                    }
                } else {
                    Button("Save") {
                        dismiss()
                    } .disabled(location.name.isEmpty)
                }
            }
        }
        //        }
        .preferredColorScheme(ColorScheme.dark)
    }
    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.secondary)
        }
    }
    
    private func formattedDateTime(_ date: Date) -> String {
        let calendar = Calendar.current
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        if calendar.isDateInToday(date) {
            return "Today, \(timeFormatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday, \(timeFormatter.string(from: date))"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            return "\(dateFormatter.string(from: date)), \(timeFormatter.string(from: date))"
        }
    }
}

#Preview {
    ModifyPin(
        location: .constant(
            Location(
                name: "Titik 1",
                coordinate: .init(latitude: -6.292363, longitude: 106.644227),
                altitude: 12,
                emoji: "📍",
                notes: ""
            )
        ),
        userLocation: CLLocation(latitude: -6.292000, longitude: 106.644000),
        onDelete: {}
    )
}

