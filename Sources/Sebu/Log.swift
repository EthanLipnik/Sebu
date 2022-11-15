//
//  SebuLog.swift
//
//
//  Created by Ethan Lipnik on 11/15/22.
//

import Foundation

internal enum LogType: String {
    case error = "🔴"
    case warning = "🟡"
    case message = "🟣"
}

internal func Log(
    _ messages: String...,
    function: String = #function,
    line: Int = #line,
    type: LogType = .message
) {
    print(type.rawValue, "Sebu", function, line, messages.joined())
}
