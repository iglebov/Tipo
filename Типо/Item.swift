//
//  Item.swift
//  Типо
//
//  Created by Ivan Glebov on 09.03.2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
