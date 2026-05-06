//
//  StartOverlay.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import SwiftUI

struct StartOverlay: View {
    let onStart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.1)

            VStack(spacing: 20) {
                Text("Are you ready to start?")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Button(action: onStart) {
                    Label("Start Trekking", systemImage: "location.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 32)
                        .background(Color.white)
                        .cornerRadius(50)
                }
            }
        }
        .ignoresSafeArea()
    }
}
