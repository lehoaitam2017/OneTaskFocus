//
//  Item.swift
//  OneTaskFocus
//
//  Created by Tam Le on 3/12/26.
//

import Foundation
import SwiftData

@Model
final class FocusSession {
    var taskTitle: String
    var sessionNote: String
    var duration: Int
    var startedAt: Date
    var endedAt: Date

    init(
        taskTitle: String,
        sessionNote: String = "",
        duration: Int,
        startedAt: Date,
        endedAt: Date
    ) {
        self.taskTitle = taskTitle
        self.sessionNote = sessionNote
        self.duration = duration
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}
