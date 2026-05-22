import SwiftUI
import SwiftData

struct TestView: View {
    @Query var items: [String]
    var engine: NSObject? = nil
    var tracker: Int? = nil
    
    init(engine: NSObject? = nil) {
        self.engine = engine
        self.tracker = 0
    }
    var body: some View { Text("Test") }
}
