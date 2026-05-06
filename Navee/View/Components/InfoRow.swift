//
//  InfoRow.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import SwiftUI

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.secondary)
        }
    }
}
