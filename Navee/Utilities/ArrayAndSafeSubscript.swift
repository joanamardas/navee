//
//  ArrayAndSafeSubscript.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
