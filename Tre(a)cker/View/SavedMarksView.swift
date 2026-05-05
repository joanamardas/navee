//
//  SavedMarksView.swift
//  Tre(a)cker
//

import SwiftUI
import CoreLocation
internal import _LocationEssentials

struct SavedMarksView: View  {
    @Binding var locations: [Location]
    @Binding var isPresented: Bool
    @State private var selectedLocation: Location?
    var onNavigate: (Location) -> Void
    @State private var locationManager = CLLocationManager()
    
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                
                // ── Header ──────────────────────────────────────────────────
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
                
                // ── List ────────────────────────────────────────────────────
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                } else {
                    List {
                        ForEach($locations) { $location in
                            MarkRow(
                                location: $location,
                                onNavigate: { onNavigate(location) },
                                onEdit: {
                                    selectedLocation = location
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
                    .background(Color.black)
                    .frame(maxWidth: .infinity,  maxHeight: .infinity)
                }
                
            }
            .background(Color.black)
            .sheet(item: $selectedLocation) { location in
                NavigationStack {
                    ModifyPin(location: safeBinding(for: location),
                              userLocation: locationManager.location, // Kirim lokasi user sekarang
                              onDelete: {
                        // Logika hapus: cari ID yang sama lalu buang dari array
                        locations.removeAll { $0.id == location.id }
                    })
                }
            }
            
            
        }
    }
    func safeBinding(for targetLocation: Location) -> Binding<Location> {
        Binding(
            get: {
                // Cari lokasi saat ini, jika tidak ketemu pakai data terakhir
                locations.first(where: { $0.id == targetLocation.id }) ?? targetLocation
            },
            set: { newValue in
                // Simpan perubahan kembali ke array
                if let index = locations.firstIndex(where: { $0.id == targetLocation.id }) {
                    locations[index] = newValue
                }
            }
        )
    }
}


// MARK: - Individual Row

struct MarkRow: View {
    @Binding var location: Location
    var onNavigate: () -> Void
    var onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.blue)
                .frame(width: 48, height: 48)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(location.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text("\(Int(location.altitude)) meter")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            HStack(spacing: 8){
                Button(action: onNavigate) {
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color(red: 0.2, green: 0.5, blue: 1.0))
                }
                .buttonStyle(.plain)
                Button("Edit") {
                    onEdit()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(red: 0.2, green: 0.5, blue: 1.0))
                .buttonStyle(.plain)
                
            }
            
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .preferredColorScheme(.dark)
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
