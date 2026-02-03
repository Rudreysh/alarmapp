import SwiftUI

struct Tag: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
    
    var color: Color {
        Color(hex: colorHex)
    }
    
    init(id: UUID = UUID(), name: String, colorHex: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}

