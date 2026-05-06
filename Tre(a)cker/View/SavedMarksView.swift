// SavedMarksView.swift

import SwiftUI
import CoreLocation

// MARK: - SavedMarksView

struct SavedMarksView: View {
    @Binding var locations: [Location]
    @Binding var isPresented: Bool
    var onNavigate: (Location) -> Void
    var userLocation: CLLocation?

    @State private var editingID: Location.ID? = nil
    @State private var navigatingToIndex: Int? = nil

    private var navPath: Binding<[Location.ID]> {
        Binding(
            get: { editingID.map { [$0] } ?? [] },
            set: { editingID = $0.first }
        )
    }

    var body: some View {
        NavigationStack(path: navPath) {
            Group {
                if locations.isEmpty {
                    EmptySavedMarksView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                } else {
                    pinList
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
                ModifyPinWrapper(
                    id: id,
                    locations: $locations,
                    userLocation: userLocation,
                    onDeleted: { editingID = nil }
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

    private var pinList: some View {
        List {
            ForEach(locations) { location in
                SavedMarkRow(
                    location:     location,
                    userLocation: userLocation,
                    onNavigate: {
                        if let idx = locations.firstIndex(where: { $0.id == location.id }) {
                            navigatingToIndex = idx
                        }
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
                location:     $locations[index],
                userLocation: userLocation,
                onDelete: {
                    locations.removeAll { $0.id == id }
                    onDeleted()
                }
            )
        }
    }
}

// MARK: - SavedMarkRow

struct SavedMarkRow: View {
    let location: Location
    var userLocation: CLLocation?
    var onNavigate: () -> Void
    var onEdit: () -> Void

    @State private var navigatePressed = false

    // Baca emoji dari location, fallback ke "mappin"
    private var iconName: String {
        location.emoji.isEmpty ? "mappin" : location.emoji
    }

    // Warna box berdasarkan icon — tiap jenis punya karakter warna sendiri
    private var iconColor: (top: Color, bottom: Color) {
        switch iconName {
        case "mappin":
            return (Color(red: 0.25, green: 0.55, blue: 1.0), Color(red: 0.08, green: 0.28, blue: 0.86))
        case "tent.fill":
            return (Color(red: 0.22, green: 0.65, blue: 0.38), Color(red: 0.10, green: 0.42, blue: 0.22))
        case "sun.max.fill":
            return (Color(red: 1.0,  green: 0.72, blue: 0.10), Color(red: 0.88, green: 0.50, blue: 0.04))
        case "water.waves":
            return (Color(red: 0.12, green: 0.68, blue: 0.90), Color(red: 0.06, green: 0.44, blue: 0.72))
        case "flag.fill":
            return (Color(red: 1.0,  green: 0.30, blue: 0.22), Color(red: 0.80, green: 0.12, blue: 0.08))
        case "mountain.2.fill":
            return (Color(red: 0.50, green: 0.42, blue: 0.36), Color(red: 0.30, green: 0.24, blue: 0.18))
        case "flame.fill":
            return (Color(red: 1.0,  green: 0.42, blue: 0.12), Color(red: 0.88, green: 0.22, blue: 0.04))
        case "binoculars.fill":
            return (Color(red: 0.40, green: 0.32, blue: 0.80), Color(red: 0.22, green: 0.14, blue: 0.60))
        default:
            return (Color(red: 0.25, green: 0.55, blue: 1.0), Color(red: 0.08, green: 0.28, blue: 0.86))
        }
    }

    private var distanceText: String {
        guard let user = userLocation else { return "—" }
        let point  = CLLocation(latitude: location.coordinate.latitude,
                                longitude: location.coordinate.longitude)
        let meters = user.distance(from: point)
        return meters < 1000
            ? "\(Int(meters)) m"
            : String(format: "%.1f km", meters / 1000)
    }

    var body: some View {
        HStack(spacing: 12) {

            // Icon pin — warna dinamis sesuai icon yang dipilih
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(
                        colors: [iconColor.top, iconColor.bottom],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 40, height: 40)
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 6) {
                    Label(distanceText, systemImage: "location.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("·").font(.subheadline).foregroundColor(.secondary.opacity(0.4))

                    Label("\(Int(location.altitude)) mdpl", systemImage: "mountain.2.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

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
                .font(.system(size: 15))
                .foregroundColor(.gray)
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    SavedMarksView(
        locations: .constant([
            Location(name: "Titik 1", coordinate: .init(latitude: -6.292363, longitude: 106.644227), altitude: 12, emoji: "tent.fill", notes: ""),
            Location(name: "Titik 2", coordinate: .init(latitude: -6.293000, longitude: 106.645000), altitude: 6,  emoji: "flame.fill", notes: ""),
            Location(name: "Titik 3", coordinate: .init(latitude: -6.291000, longitude: 106.643000), altitude: 34, emoji: "", notes: "")
        ]),
        isPresented: .constant(true),
        onNavigate: { _ in }
    )
}
