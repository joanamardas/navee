import SwiftUI

struct ModifyPin: View {
    @Environment(\.dismiss) var dismiss

    @State private var name: String = "Checkpoint 1"
    @State private var emoji: String = "📍"
    @State private var notes: String = ""

    @FocusState private var isEmojiFieldFocused: Bool

    // Mock data
    let latitude: Double = -6.2000
    let longitude: Double = 106.8166
    let createdDate = Date()
    let distance: Double = 125

    var body: some View {
        NavigationView {
            //Color.black.edgesIgnoringSafeArea(.all)
            
            Form {
                
                // MARK: - Editable: Name
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
                
                // MARK: - Editable: Notes
                Section {
                    TextField("Add a note", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            
                // MARK: - Read Only: Details
                VStack(spacing: 16) {
                        
                       //header: Text("Details"))
                        // Distance
                        detailRow(
                            label: "Distance",
                            value: "\(Int(distance)) m away"
                        )

                        Divider()

                        // Coordinates
                        detailRow(
                            label: "Coordinates",
                            value: "\(latitude, default: "%.4f"), \(longitude, default: "%.4f")"
                        )

                        Divider()

                        // DateTime
                        detailRow(
                            label: "Saved",
                            value: formattedDateTime(createdDate)
                        )
                    }
                    .padding(.vertical, 4)
                

                // MARK: - Delete
                Section {
                        Button(role: .destructive) {
                            // delete action
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
                        } .disabled(name.isEmpty)
                    }
                }
            }
        }
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
    ModifyPin()
}


