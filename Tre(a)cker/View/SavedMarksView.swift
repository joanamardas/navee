//
//  SavedMarksView.swift
//  Tre(a)cker
//

import SwiftUI
internal import _LocationEssentials

struct SavedMarksView: View {
    @Binding var locations: [Location]
    var onNavigate: (Location) -> Void
    var onDelete: (Location) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Saved Marks")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

            if locations.isEmpty {
                VStack {
                    Spacer()
                    Text("No marks saved yet.")
                        .foregroundColor(.gray)
                        .font(.system(size: 15))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 13) {
                        ForEach(locations) { location in
                            SavedMarkCard(
                                location: location,
                                onNavigate: { onNavigate(location) },
                                onDelete: { onDelete(location) }
                            )
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
    }
}

// MARK: - Individual Card

struct SavedMarkCard: View {
    let location: Location
    var onNavigate: () -> Void
    var onDelete: () -> Void

    @State private var isExpanded: Bool = false

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: location.timestamp)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "flag.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 2) {
                    Text(location.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.black)
                    Text(timeString)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.gray)
                    .font(.system(size: 13))
            }
            .frame(maxWidth: .infinity, minHeight: 71, maxHeight: 71)
            .padding(.horizontal, 16)
            .background(Color.white)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                HStack(spacing: 10) {
                    Button(action: onNavigate) {
                        Text("Navigate")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.orange)
                            .cornerRadius(10)
                    }

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.system(size: 16))
                            .padding(10)
                            .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white)
            }
        }
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
    }
}

#Preview {
    SavedMarksView(
        locations: .constant([
            Location(name: "Titik 1", coordinate: .init(latitude: -6.292363, longitude: 106.644227)),
            Location(name: "Titik 2", coordinate: .init(latitude: -6.293000, longitude: 106.645000)),
            Location(name: "Titik 3", coordinate: .init(latitude: -6.291000, longitude: 106.643000))
        ]),
        onNavigate: { _ in },
        onDelete: { _ in }
    )
}
