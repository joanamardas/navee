import SwiftUI
import CoreLocation

// MARK: - SavedMarksView

struct SavedMarksView: View {
    @Binding var locations: [Location]
    @Binding var isPresented: Bool
    var onNavigate: (Location) -> Void
    var userLocation: CLLocation?

    @State private var selectedLocationID: Location.ID? = nil
    @State private var navigatingToIndex:  Int?         = nil

    private var pathBinding: Binding<[Location.ID]> {
        Binding(
            get: { selectedLocationID.map { [$0] } ?? [] },
            set: { selectedLocationID = $0.first }
        )
    }

    var body: some View {
        NavigationStack(path: pathBinding) {
            Group {
                if locations.isEmpty {
                    EmptySavedMarksView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                } else {
                    List {
                        ForEach(locations) { location in
                            SavedMarkRow(
                                location: location,
                                locations: $locations,
                                userLocation: userLocation,
                                onNavigate: {
                                    if let idx = locations.firstIndex(where: { $0.id == location.id }) {
                                        navigatingToIndex = idx
                                    }
                                },
                                onEdit: { selectedLocationID = location.id }
                            )
                            .listRowBackground(Color.black)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .listRowSeparatorTint(Color.white.opacity(0.1))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(location)
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
            }
            .background(Color.black)
            .navigationTitle("Saved Points")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                }
            }
            .navigationDestination(for: Location.ID.self) { id in
                ModifyPinDestination(
                    id: id,
                    locations: $locations,
                    userLocation: userLocation,
                    onDeleted: { selectedLocationID = nil }
                )
            }
            .fullScreenCover(isPresented: Binding(
                get: { navigatingToIndex != nil },
                set: { if !$0 { navigatingToIndex = nil } }
            )) {
                if let idx = navigatingToIndex {
                    CompassNavigationView(
                        allLocations:     locations,
                        destinationIndex: idx,
                        onEndNavigation:  { navigatingToIndex = nil }
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func delete(_ location: Location) {
        locations.removeAll { $0.id == location.id }
    }
}

// MARK: - ModifyPin Destination Wrapper

private struct ModifyPinDestination: View {
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
        } else {
            EmptyView()
        }
    }
}

// MARK: - SavedMarkRow

struct SavedMarkRow: View {
    let location: Location
    @Binding var locations: [Location]
    var userLocation: CLLocation?
    var onNavigate: () -> Void
    var onEdit: () -> Void

    private var distanceText: String {
        guard let user = userLocation else { return "—" }
        let point  = CLLocation(latitude: location.coordinate.latitude,
                                longitude: location.coordinate.longitude)
        let meters = user.distance(from: point)
        return meters < 1000
            ? "\(Int(meters)) m"
            : String(format: "%.1f km", meters / 1000)
    }

    @State private var navigatePressed = false

    var body: some View {
        HStack(spacing: 12) {

            // ── Pin icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.18, green: 0.45, blue: 1.0),
                                 Color(red: 0.08, green: 0.28, blue: 0.86)],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 40, height: 40)
                    .shadow(color: Color.blue.opacity(0.35), radius: 4, x: 0, y: 2)
                Image(systemName: "mappin")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }

            // ── Name + Meta
            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill").font(.caption2)
                        Text(distanceText).font(.subheadline)
                    }
                    .foregroundColor(.secondary)

                    Text("·").font(.subheadline).foregroundColor(.secondary.opacity(0.4))

                    HStack(spacing: 3) {
                        Image(systemName: "mountain.2.fill").font(.caption2)
                        Text("\(Int(location.altitude)) mdpl").font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            // ── Navigate button
            Button(action: onNavigate) {
                Image(systemName: navigatePressed ? "location.circle.fill" : "location.circle")
                    .font(.system(size: 26))
                    .foregroundColor(.blue)
                    .symbolEffect(.bounce, value: navigatePressed)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in navigatePressed = true }
                    .onEnded   { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            navigatePressed = false
                        }
                    }
            )

            Button("Edit", action: onEdit)
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .font(.subheadline)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Empty State

private struct EmptySavedMarksView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.gray.opacity(0.4))
            Text("No points saved yet.")
                .foregroundColor(.gray)
                .font(.system(size: 15))
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    SavedMarksView(
        locations: .constant([
            Location(name: "Titik 1", coordinate: .init(latitude: -6.292363, longitude: 106.644227), altitude: 12, emoji: "", notes: ""),
            Location(name: "Titik 2", coordinate: .init(latitude: -6.293000, longitude: 106.645000), altitude: 6,  emoji: "", notes: ""),
            Location(name: "Titik 3", coordinate: .init(latitude: -6.291000, longitude: 106.643000), altitude: 34, emoji: "", notes: "")
        ]),
        isPresented: .constant(true),
        onNavigate: { _ in }
    )
    .preferredColorScheme(.dark)
}
