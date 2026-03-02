import SwiftUI

func test() -> some View {
    ProgressView(timerInterval: Date()...Date(), countsDown: true)
}
