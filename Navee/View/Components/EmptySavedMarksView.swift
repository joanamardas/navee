//
//  EmptySavedMarksView.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import SwiftUI

struct EmptySavedMarksView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.gray.opacity(0.4))
            Text("No points saved yet.")
                .font(.system(size: 15))
                .foregroundColor(.gray)
            Spacer()
        }
    }
}
