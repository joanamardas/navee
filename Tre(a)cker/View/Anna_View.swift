//
//  Anna_View.swift
//  Tre(a)cker
//

import SwiftUI
internal import _LocationEssentials

struct Anna_View: View {
    @Binding var locations: [Location]
    @Binding var isPresented: Bool
    var onNavigate: (Location) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

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
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(locations) { location in
                        AnnaMarkRow(
                            location: location,
                            onNavigate: { onNavigate(location) }
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
        .cornerRadius(16)
    }
}

// MARK: - Individual Row

struct AnnaMarkRow: View {
    let location: Location
    var onNavigate: () -> Void

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

            Button(action: onNavigate) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color(red: 0.2, green: 0.5, blue: 1.0))
            }

            Text("Edit")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(red: 0.2, green: 0.5, blue: 1.0))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    Anna_View(
        locations: .constant([
            Location(name: "Titik 1", coordinate: .init(latitude: -6.292363, longitude: 106.644227), altitude: 12, emoji: ""),
            Location(name: "Titik 2", coordinate: .init(latitude: -6.293000, longitude: 106.645000), altitude: 6,  emoji: ""),
            Location(name: "Titik 3", coordinate: .init(latitude: -6.291000, longitude: 106.643000), altitude: 34, emoji: "")
        ]),
        isPresented: .constant(true),
        onNavigate: { _ in }
    )
    .preferredColorScheme(.dark)
}
