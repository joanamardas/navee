//
//  SavedMarkRow.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import SwiftUI
import CoreLocation

struct SavedMarkRow: View {
    let location: Location
    var userLocation: CLLocation?
    //    var onNavigate: () -> Void
    var onSelect: () -> Void
    var onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            PinIconBox(emoji: location.emoji)
            
            locationInfo
            
            Spacer()
            
            //            NavigateButton(action: onNavigate)
            //                .buttonStyle(.borderless)
            
            Button("Edit", action: onEdit)
                .buttonStyle(.borderless)
                .foregroundColor(.blue)
                .font(.subheadline)
        }
        .padding(.vertical, 20)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
    
    // MARK: - Subviews
    
    private var locationInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(location.name)
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 6) {
                Text(location.formattedDistance(from: userLocation))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("·")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.4))
                
                Text("\(Int(location.altitude)) mdpl")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - NavigateButton

private struct NavigateButton: View {
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: isPressed ? "location.circle.fill" : "location.circle")
                .font(.system(size: 26))
                .foregroundColor(.blue)
                .symbolEffect(.bounce, value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Preview

#Preview {
    List {
        SavedMarkRow(
            location: Location(
                name: "Titik 1",
                coordinate: .init(latitude: -6.292363, longitude: 106.644227),
                altitude: 12,
                emoji: "tent.fill",
                notes: ""
            ),
            userLocation: CLLocation(latitude: -6.293, longitude: 106.645),
            //            onNavigate: {},
            onSelect: {  },
            onEdit: {}
            
        )
        .listRowBackground(Color.black)
    }
    .listStyle(.plain)
    .preferredColorScheme(.dark)
}

