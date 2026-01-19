import Foundation

struct BarcodeRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let rawValue: String
    var displayName: String?
    let createdAt: Date
    let symbology: String?
    
    init(id: UUID = UUID(), rawValue: String, displayName: String? = nil, symbology: String? = nil) {
        self.id = id
        self.rawValue = rawValue
        self.displayName = displayName
        self.createdAt = Date()
        self.symbology = symbology
    }
}

// Config stored in the AlarmMission.config dictionary
struct QRBarcodeMissionConfig: Codable, Equatable {
    var selectedBarcodeId: UUID?
    var selectedRawValueFallback: String? 
    var soundEnabledDuringMission: Bool = true
}
