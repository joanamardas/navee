import SwiftUI
import CoreLocation

struct SavedMarksView: View {
    @Binding var locations: [Location]
    @Binding var isPresented: Bool
    var onNavigate: (Location) -> Void
    var onSelect: (Location) -> Void
    var userLocation: CLLocation?
    
    @State private var editingID: Location.ID? = nil
    @State private var compassIndex: Int? = nil
    
    // Konversi editingID ↔ NavigationStack path
    private var navPath: Binding<[Location.ID]> {
        Binding(
            get: { editingID.map { [$0] } ?? [] },
            set: { editingID = $0.first }
        )
    }
    
    private var compassBinding: Binding<Bool> {
        Binding(
            get: { compassIndex != nil },
            set: { if !$0 { compassIndex = nil } }
        )
    }
    
    var body: some View {
        NavigationStack(path: navPath) {
            content
                .background(Color.black)
                .navigationTitle("Saved Points")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { isPresented = false }
                    }
                }
                .navigationDestination(for: Location.ID.self) { id in
                    ModifyPinWrapper(
                        id: id,
                        locations: $locations,
                        userLocation: userLocation,
                        onDeleted: { editingID = nil }
                    )
                }
                .fullScreenCover(isPresented: compassBinding) {
                    if let idx = compassIndex {
                        CompassNavigationView(
                            allLocations: locations,
                            destinationIndex: idx,
                            onEndNavigation: { compassIndex = nil }
                        )
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        if locations.isEmpty {
            EmptySavedMarksView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        } else {
            pinList
        }
    }
    
    private var pinList: some View {
        List {
            ForEach(locations) { location in
                SavedMarkRow(
                    location: location,
                    userLocation: userLocation,
                    onSelect: {
                        onSelect(location)
                    },
                    onEdit: { editingID = location.id }
                )
                .listRowBackground(Color.black)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
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
        .background(Color.black)
    }
    
    // MARK: - Actions
    
    private func openCompass(for location: Location) {
        if let idx = locations.firstIndex(where: { $0.id == location.id }) {
            compassIndex = idx
        }
    }
}

// MARK: - ModifyPin Wrapper

private struct ModifyPinWrapper: View {
    let id: Location.ID
    @Binding var locations: [Location]
    var userLocation: CLLocation?
    var onDeleted: () -> Void
    
    var body: some View {
        if let index = locations.firstIndex(where: { $0.id == id }) {
            ModifyPin(
                location: $locations[index],
                userLocation: userLocation,
                onDelete: {
                    locations.removeAll { $0.id == id }
                    onDeleted()
                }
            )
        }
    }
}

// MARK: - Preview

#Preview {
    SavedMarksView(
        locations: .constant([
            Location(name: "Titik 1",
                     coordinate: .init(latitude: -6.292363, longitude: 106.644227),
                     altitude: 12, emoji: "tent.fill",  notes: ""),
            Location(name: "Titik 2",
                     coordinate: .init(latitude: -6.293000, longitude: 106.645000),
                     altitude: 6,  emoji: "flame.fill", notes: ""),
            Location(name: "Titik 3",
                     coordinate: .init(latitude: -6.291000, longitude: 106.643000),
                     altitude: 34, emoji: "",           notes: "")
        ]),
        isPresented: .constant(true),
        onNavigate: { _ in },
        onSelect: { _ in }
    )
}
