//
//  GlassButtonStyle.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import SwiftUI

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(
                .spring(response: 0.2, dampingFraction: 0.6),
                value: configuration.isPressed
            )
    }
}
