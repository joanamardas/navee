import SwiftUI
import _LocationEssentials

struct SavedMarksView: View {
    @Binding var locations: [Location]
    @Binding var isPresented: Bool
    var onNavigate: (Location) -> Void
    var userLocation: CLLocation?
    
    @State private var editingLocation: Location? = nil   // ← track edit di sini
    
    var body: some View {
        Group {
            if let loc = editingLocation {
                // ── Halaman Edit
                NavigationStack {
                    ModifyPin(
                        location: loc,
                        onSave: { updated in
                            if let idx = locations.firstIndex(where: { $0.id == updated.id }) {
                                locations[idx] = updated
                            }
                            editingLocation = nil   // balik ke list
                        },
                        onDelete: {
                            locations.removeAll { $0.id == loc.id }
                            editingLocation = nil
                        }
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Back") {
                                editingLocation = nil   // ← swipe back / tap back
                            }
                        }
                    }
                }
                .transition(.move(edge: .trailing))   // ← animasi slide dari kanan
            } else {
                // ── Halaman List
                listView
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: editingLocation == nil)
        .preferredColorScheme(.dark)
    }
    
    private var listView: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saved Point")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(locations.count) Point")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            if locations.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No points saved yet.")
                        .foregroundColor(.gray)
                        .font(.system(size: 15))
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(locations) { location in
                        SavedMarkRow(                        // ← pakai SavedMarkRow
                            location: location,
                            locations: $locations,
                            userLocation: userLocation,     // ← pass userLocation
                            onNavigate: {
                                isPresented = false
                                onNavigate(location)
                            },
                            onEdit: {
                                withAnimation {
                                    editingLocation = location
                                }
                            }
                        )
                        .listRowBackground(Color.black)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparatorTint(Color.white.opacity(0.1))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                locations.removeAll { $0.id == location.id }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }
}
