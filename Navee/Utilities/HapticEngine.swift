//
//  HapticEngine.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import UIKit

enum HapticEngine {

    static func wrongWay() {
        let g = UINotificationFeedbackGenerator()
        g.prepare()
        g.notificationOccurred(.warning)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            let impact = UIImpactFeedbackGenerator(style: .rigid)
            impact.prepare()
            impact.impactOccurred()
        }
    }

    static func backOnTrack() {
        let g = UIImpactFeedbackGenerator(style: .soft)
        g.prepare()
        g.impactOccurred()
    }

    static func arrived() {
        let g = UINotificationFeedbackGenerator()
        g.prepare()
        g.notificationOccurred(.success)
    }
}
