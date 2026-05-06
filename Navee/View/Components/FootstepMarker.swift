//
//  FootstepMarker.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import SwiftUI

struct FootstepMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.18))
                .frame(width: 44, height: 44)
            Circle()
                .fill(Color.white)
                .frame(width: 30, height: 30)
            Image(systemName: "figure.walk")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.blue)
        }
    }
}
