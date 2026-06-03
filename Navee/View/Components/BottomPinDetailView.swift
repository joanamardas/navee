//
//  BottomPinDetailView.swift
//  Navee
//

import SwiftUI
import CoreLocation

struct BottomPinDetailView: View {
    let location:     Location
    var userLocation: CLLocation?
    var onNavigate:   () -> Void
    var onEdit:       () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // MARK: Header
            HStack(spacing: 14) {
                PinIconBox(emoji: location.emoji, size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    LocationMetaRow(location: location, userLocation: userLocation)

                    Text(location.timestamp.relativeFormatted())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Photo preview — only shown when the user has added a photo
            if let data = location.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button(action: onNavigate) {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                    Text("Navigate")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)               // ← fixed height
                .background(Color.blue)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // MARK: Edit — secondary (iOS 26 Liquid Glass)
            Button(action: onEdit) {
                Label("Edit Point", systemImage: "pencil")
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)           // ← sama persis
                    .glassEffect(in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BottomPinDetailView(
            location: Location(
                name:       "Titik 1",
                coordinate: .init(latitude: -6.292363, longitude: 106.644227),
                altitude:   12,
                emoji:      "mappin",
                notes:      ""
            ),
            userLocation: CLLocation(latitude: -6.293000, longitude: 106.645000),
            onNavigate: {},
            onEdit:     {}
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
    .frame(height: 270)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
