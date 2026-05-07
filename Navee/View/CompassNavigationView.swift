//
//  CompassNavigationView.swift
//  Navee
//

import SwiftUI
import CoreLocation

struct CompassNavigationView: View {
    let allLocations: [Location]
    let destinationIndex: Int
    var onEndNavigation: () -> Void

    @StateObject private var tracker = LocationTracker()

    @State private var nav               = NavState()
    @State private var currentStep       = 0
    @State private var arrivalFlash: ArrivalKind? = nil
    @State private var flashOpacity: Double = 0
    @State private var wasOnTrack        = true
    @State private var wasArrived        = false
    @State private var showEndConfirm    = false

    // MARK: - Computed Properties

    private var breadcrumbs: [Location] {
        guard destinationIndex < allLocations.count else { return [] }
        let lastIndex = allLocations.count - 1
        guard lastIndex > destinationIndex else {
            return [allLocations[destinationIndex]]
        }
        return (destinationIndex..<lastIndex).reversed().map { allLocations[$0] }
    }

    private var currentTarget: Location?    { breadcrumbs[safe: currentStep] }
    private var finalDestination: Location? { breadcrumbs.last }
    private var totalSteps: Int             { breadcrumbs.count }
    private var isLastStep: Bool            { currentStep >= totalSteps - 1 }
    private var finalArrived: Bool          { nav.hasArrived && isLastStep }
    private var pointsPassed: Int           { nav.hasArrived ? currentStep + 1 : currentStep }

    private var distanceToFinal: Double {
        guard let userLocation = tracker.userLocation else { return 0 }
        let remaining = Array(breadcrumbs.dropFirst(currentStep))
        guard !remaining.isEmpty else { return 0 }
        var total = 0.0
        var prev  = userLocation.coordinate
        for waypoint in remaining {
            total += prev.distance(to: waypoint.coordinate)
            prev   = waypoint.coordinate
        }
        return total
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            // Compass + status label
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 0) {
                    if let target = currentTarget {
                        CompassView(nav: nav, destination: target)
                            .padding(.horizontal, 32)
                    }
                    StatusLabel(nav: nav, finalArrived: finalArrived)
                        .padding(.top, 28)
                        .animation(.easeInOut(duration: 0.3), value: finalArrived)
                }
                .opacity(finalArrived ? 0 : 1)
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: finalArrived)

                Spacer(minLength: 32)
                Color.clear.frame(height: 200)
            }

            // Dim overlay saat arrived
            if finalArrived {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.35), value: finalArrived)
            }

            // Bottom nav card
            BottomNavCard(
                nav:              nav,
                finalArrived:     finalArrived,
                currentTarget:    currentTarget,
                finalDestination: finalDestination,
                distanceToFinal:  distanceToFinal,
                pointsPassed:     pointsPassed,
                totalSteps:       totalSteps,
                onEndNavigation: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showEndConfirm = true
                    }
                },
                onExit: {
                    onEndNavigation()
                }
            )

            // Checkpoint flash overlay
            if let flash = arrivalFlash, flash == .checkpoint {
                ArrivalFlashOverlay(kind: flash, opacity: flashOpacity)
                    .allowsHitTesting(false)
            }

            // End Navigation modal — reusable ConfirmAlertModal
            if showEndConfirm {
                ConfirmAlertModal(
                    icon: "xmark.circle.fill",
                    iconTint: Color(red: 1.0, green: 0.33, blue: 0.30),
                    title: "End Navigation?",
                    message: "Your current navigation session\nwill be stopped.",
                    confirmLabel: "End",
                    confirmTint: Color(red: 1.0, green: 0.33, blue: 0.30),
                    onCancel: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showEndConfirm = false
                        }
                    },
                    onConfirm: {
                        onEndNavigation()
                    }
                )
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showEndConfirm)
        .onAppear    { tracker.startTracking() }
        .onDisappear { tracker.stopTracking()  }
        .onChange(of: tracker.heading) { _, heading in
            nav.userHeading = heading
            if !nav.hasValidHeading { nav.hasValidHeading = true }
            updateNav(from: tracker.userLocation)
        }
        .onChange(of: tracker.userLocation) { _, location in
            updateNav(from: location)
            checkArrival()
        }
        .onChange(of: nav.isOnTrack) { _, onTrack in
            guard !nav.hasArrived else { return }
            onTrack ? HapticEngine.backOnTrack() : HapticEngine.wrongWay()
        }
        .onChange(of: nav.hasArrived) { _, arrived in
            if arrived && !wasArrived { HapticEngine.arrived() }
            wasArrived = arrived
        }
    }

    // MARK: - Actions

    private func updateNav(from location: CLLocation?) {
        guard let coord = location?.coordinate, let target = currentTarget else { return }
        nav.bearing  = coord.bearing(to: target.coordinate)
        nav.distance = coord.distance(to: target.coordinate)
    }

    private func checkArrival() {
        guard nav.hasArrived else { return }
        guard !isLastStep else { return }
        triggerFlash(.checkpoint) {
            withAnimation(.easeInOut(duration: 0.4)) { currentStep += 1 }
            wasArrived = false
            updateNav(from: tracker.userLocation)
        }
    }

    private func triggerFlash(_ kind: ArrivalKind, completion: (() -> Void)? = nil) {
        guard arrivalFlash == nil else { return }
        arrivalFlash = kind
        withAnimation(.easeOut(duration: 0.2)) { flashOpacity = 1 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeIn(duration: 0.35)) { flashOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                arrivalFlash = nil
                completion?()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CompassNavigationView(
        allLocations: [
            Location(name: "Titik 1", coordinate: .init(latitude: -6.291, longitude: 106.643), altitude: 10, emoji: "mappin",     notes: ""),
            Location(name: "Titik 2", coordinate: .init(latitude: -6.292, longitude: 106.644), altitude: 20, emoji: "tent.fill",  notes: ""),
            Location(name: "Titik 3", coordinate: .init(latitude: -6.293, longitude: 106.645), altitude: 30, emoji: "flag.fill",  notes: ""),
            Location(name: "Titik 4", coordinate: .init(latitude: -6.294, longitude: 106.646), altitude: 40, emoji: "flame.fill", notes: ""),
        ],
        destinationIndex: 1,
        onEndNavigation: {}
    )
}
