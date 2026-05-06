//
//  BottomPinDetailView.swift
//  Navee
//
//  Created by Rosamond Patricia Selamat Lie on 06/05/26.
//
import SwiftUI
import CoreLocation

struct BottomPinDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    let location: Location
    var userLocation: CLLocation?
    var onNavigate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // Icon + Info row
            HStack(spacing: 16) {
                PinIconBox(emoji: location.emoji, size: 56)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(location.name)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    
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
                    
                    Text(formattedDate(location.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 30)
                
                Spacer()
                
//                Button(action: { dismiss() }, label: {
//                    Image(systemName: "xmark.circle")
//                })
            }
            
            // Navigate button — full width
            Button(action: onNavigate) {
                HStack(spacing: 10) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Navigate")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .cornerRadius(50)
            }
            .buttonStyle(.plain)
            
            // Extra bottom padding for home indicator
            Spacer().frame(height: 8)
        }
        
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }
        
        
        func formattedDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        VStack {
            Spacer()
            BottomPinDetailView(
                location: Location(
                    name: "Titik 1",
                    coordinate: .init(latitude: -6.292363, longitude: 106.644227),
                    altitude: 12,
                    emoji: "mappin",
                    notes: ""
                ),
                userLocation: CLLocation(latitude: -6.293000, longitude: 106.645000),
                onNavigate: {}
            )
            .background(.ultraThinMaterial)
            .cornerRadius(20, corners: [.topLeft, .topRight])
        }
        .ignoresSafeArea(edges: .bottom)
    }
    .preferredColorScheme(.dark)
}
