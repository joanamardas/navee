//
//  NavState.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import CoreLocation

// MARK: - Nav Constants

enum Nav {
    static let arrivalRadius: Double    = 10
    static let onTrackTolerance: Double = 30
    static let pinMaxDistance: Double   = 500
    static let pinMinRatio: CGFloat     = 0.18
}

// MARK: - ArrivalKind

enum ArrivalKind {
    case checkpoint
    case final
}

// MARK: - NavState

struct NavState {
    var userHeading: Double  = 0
    var bearing: Double      = 0
    var distance: Double     = 0
    var hasValidHeading: Bool = false

    var hasArrived: Bool {
        distance > 0 && distance <= Nav.arrivalRadius
    }

    var isOnTrack: Bool {
        guard distance > 0, hasValidHeading, !hasArrived else { return false }
        return abs(angleDiff(from: userHeading, to: bearing)) <= Nav.onTrackTolerance
    }

    private func angleDiff(from a: Double, to b: Double) -> Double {
        var d = b - a
        while d >  180 { d -= 360 }
        while d < -180 { d += 360 }
        return d
    }
}
