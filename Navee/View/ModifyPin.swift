//
//  ModifyPin.swift
//  Navee
//
import SwiftUI
import CoreLocation

struct ModifyPin: View {
    @Environment(\.dismiss) var dismiss
    @Binding var location: Location
    var userLocation: CLLocation?
    var onSave:   () -> Void
    var onDelete: () -> Void
    
    @State private var draft: Location
    @State private var showDeleteAlert = false  // tambah ini
    
    private let nameLimit = 20
    
    init(
        location: Binding<Location>,
        userLocation: CLLocation?,
        onSave: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self._location    = location
        self.userLocation = userLocation
        self.onSave       = onSave
        self.onDelete     = onDelete
        self._draft       = State(initialValue: location.wrappedValue)
    }
    
    var body: some View {
        ZStack {
            Form {
                nameSection
                iconSection
                infoSection
                deleteSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Edit Point")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        location = draft
                        onSave()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(draft.name.isEmpty)
                }
            }
            .preferredColorScheme(.dark)
            .alert("Are you sure you want to delete  this location?", isPresented: $showDeleteAlert) {
                
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                
                Button("Cancel", role: .cancel) { }
                
            } message: {
                Text("This action cannot be undone.")
            }
            
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: showDeleteAlert)
    }
    
    // MARK: - Name
    
    private var nameSection: some View {
        Section {
            HStack {
                TextField("Point name", text: Binding(
                    get: { draft.name },
                    set: { draft.name = String($0.prefix(nameLimit)) }
                ))
                Spacer()
                Text("\(draft.name.count)/\(nameLimit)")
                    .font(.caption)
                    .foregroundStyle(draft.name.count >= nameLimit ? .red : .secondary)
                    .monospacedDigit()
            }
        }
    }
    
    // MARK: - Icon
    
    private var iconSection: some View {
        Section {
            IconPicker(selectedIcon: $draft.emoji)
        }
    }
    
    // MARK: - Info
    
    private var infoSection: some View {
        Section {
            InfoRow(
                label: "Distance",
                value: draft.formattedDistance(from: userLocation, suffix: "away")
            )
            InfoRow(
                label: "Altitude",
                value: "\(Int(draft.altitude)) masl"
            )
            InfoRow(
                label: "Coordinates",
                value: String(
                    format: "%.4f, %.4f",
                    draft.coordinate.latitude,
                    draft.coordinate.longitude
                )
            )
            InfoRow(
                label: "Saved",
                value: draft.timestamp.relativeFormatted()
            )
        }
    }
    
    // MARK: - Delete
    
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    showDeleteAlert = true  // tampilkan alert, bukan langsung delete
                }
            } label: {
                Text("Delete Location")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ModifyPin(
            location: .constant(Location(
                name:       "Point 1",
                coordinate: .init(latitude: -6.2, longitude: 106.8166),
                altitude:   12,
                emoji:      "flame.fill",
                notes:      ""
            )),
            userLocation: CLLocation(latitude: -6.2012, longitude: 106.8154),
            onSave:   {},
            onDelete: {}
        )
    }
    .preferredColorScheme(.dark)
}
