//
//  MainView.swift
//  Tre(a)cker
//
//  Created by Rosamond Patricia Selamat Lie on 01/05/26.
//

import SwiftUI
import MapKit

struct MainView: View {
    @State private var mapPosition: MapCameraPosition = .region(MKCoordinateRegion(center: .init(latitude: -6.715290116344274, longitude: 106.73303228539615), latitudinalMeters: 1300, longitudinalMeters: 1300))
    
    @State private var locationManager = CLLocationManager()
    
    @State private var locations: [Location] = []
    
//    @State private var route: MKRoute?
    @State private var straightLineCoordinates: [CLLocationCoordinate2D] = []
    
    @State private var showSavedMarks: Bool = false

    @State private var pinCounter: Int = 0
    
    var body: some View {
        ZStack {
            Map(position: $mapPosition) {
                if !locations.isEmpty {
                    ForEach(locations) { location in
                         Annotation(location.name, coordinate: location.coordinate, anchor: .center){
                             Text(location.emoji)
                                     .font(.system(size: 20))
                                     .padding(8)
                                     .background(.black)
                                     .clipShape(Circle())
                                         .overlay(
                                             Circle()
                                                 .stroke(.blue, lineWidth: 1)
                                         )
                                     .shadow(radius: 3)
                        }
                    }
                }
                
                UserAnnotation()
                
                if !straightLineCoordinates.isEmpty {
                    MapPolyline(coordinates: straightLineCoordinates)
                        .stroke(.blue, lineWidth: 4)
                }
                
            }
            .mapStyle(.standard(elevation: .realistic))
            .preferredColorScheme(.dark)
            .mapControls{
                MapUserLocationButton()
                MapCompass()
                MapPitchToggle()
                MapScaleView()
            }
            .onAppear{
                locationManager.requestWhenInUseAuthorization()
                if let coordinate = locationManager.location?.coordinate {
                    mapPosition = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 1300, longitudinalMeters: 1300))
                }
            }

            VStack{
                Spacer()
                HStack(spacing: 16) {
                    // Saved Marks list button (flag icon with badge)
                    ZStack(alignment: .topTrailing) {
                        Button(action: { showSavedMarks.toggle() }) {
                            Image(systemName: "flag")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                        if !locations.isEmpty {
                            Text("\(locations.count)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.orange)
                                .clipShape(Circle())
                                .offset(x: 4, y: -4)
                        }
                    }

                    // Add Mark button
                    Button(action: createAnnotation) {
                        Text("ADD MARK")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.orange)
                            .cornerRadius(14)
                    }

                    // Navigate to last pin button
                    Button(action: {
                        if let last = locations.last {
                            getDirections(to: last)
                        }
                    }) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
            
        }
        .sheet(isPresented: $showSavedMarks) {
            Anna_View(
                locations: $locations,
                isPresented: $showSavedMarks,
                onNavigate: { location in
                    showSavedMarks = false
                    getDirections(to: location)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.black)
        }
    }
    
    func createAnnotation(){
        if let coordinate = locationManager.location?.coordinate{
            print(coordinate) // tes ambil koor
            let newLocation = Location(name: "PIN" + String(locations.count + 1), coordinate: coordinate, altitude: locationManager.location?.altitude ?? 0, emoji: "📍")
            print(newLocation.altitude)
            print(newLocation.name) // tes print nama tiitk
            locations.append(newLocation)
            pinCounter += 1
        }
    
    }
    
    func getUserLocation() async -> CLLocationCoordinate2D? {
        let updates = CLLocationUpdate.liveUpdates()
        
        do {
            let update = try await updates.first { $0.location?.coordinate != nil }
            
            return update?.location?.coordinate
        } catch {
            print("Cannot get user location")
            return nil
        }
    }
    
    func getDirections(to destination: Location) {
        Task {
            for try await update in CLLocationUpdate.liveUpdates() {
                guard let userCoordinate = update.location?.coordinate else { continue }

                await MainActor.run {
                    // Remove pins the user has already reached
                    locations.removeAll { isNear(userCoordinate, $0.coordinate) }

                    // Find destination in the list
                    guard let destIndex = locations.firstIndex(where: { $0.id == destination.id }) else {
                        straightLineCoordinates = []
                        return
                    }

                    // Retrace: from current location, go through pins AFTER destination
                    // in descending order (newest first), then arrive at destination
                    // e.g. pins = [pin1, pin2, pin3, pin4, pin5], destination = pin3
                    // waypoints = [pin5, pin4] then pin3
                    let waypoints = locations[(destIndex + 1)...]
                        .sorted { $0.timestamp > $1.timestamp } // pin5 → pin4

                    var routeCoordinates: [CLLocationCoordinate2D] = [userCoordinate]
                    for pin in waypoints {
                        routeCoordinates.append(pin.coordinate)
                    }
                    routeCoordinates.append(destination.coordinate)

                    straightLineCoordinates = routeCoordinates
                }
            }
        }
    }
    
    func isNear(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        let loc1 = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let loc2 = CLLocation(latitude: b.latitude, longitude: b.longitude)

        return loc1.distance(from: loc2) < 15 // mau hilang garisnya jika sudah mendekati berapa meteer
    }
        
    
}

#Preview {
    MainView()
}


