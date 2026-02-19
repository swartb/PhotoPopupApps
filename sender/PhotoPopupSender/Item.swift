//
//  Item.swift
//  PhotoPopupSender
//
//  Created by Bart Swart on 18/02/2026.
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
