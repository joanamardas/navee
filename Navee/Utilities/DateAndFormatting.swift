//
//  DateFormatting.swift
//  Navee
//
//  Created by neena on 06/05/26.
//

import Foundation

extension Date {
    /// "Today, 14:30" / "Yesterday, 09:00" / "12 May 2025, 08:45"
    func relativeFormatted() -> String {
        let cal = Calendar.current
        let time = DateFormatter()
        time.timeStyle = .short

        if cal.isDateInToday(self)     { return "Today, \(time.string(from: self))" }
        if cal.isDateInYesterday(self) { return "Yesterday, \(time.string(from: self))" }

        let date = DateFormatter()
        date.dateStyle = .medium
        return "\(date.string(from: self)), \(time.string(from: self))"
    }
}
