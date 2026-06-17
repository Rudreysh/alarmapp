import AVFoundation
import Combine
import SwiftUI
import UIKit

struct XPToast: Identifiable, Equatable {
    let id = UUID()
    let amount: Int
    let title: String
    let isMajor: Bool
}

struct RankUpPresentation: Identifiable, Equatable {
    let id = UUID()
    let rank: RankLevel
    let xpToNextRank: Int
}

@MainActor
final class RewardFeedbackService: ObservableObject {
    static let shared = RewardFeedbackService()

    @Published var toast: XPToast?
    @Published var rankUp: RankUpPresentation?

    private var audioPlayer: AVAudioPlayer?
    private var pendingAmount = 0
    private var pendingTitle = "XP"
    private var flushTask: Task<Void, Never>?

    private init() {}

    func handle(_ result: XPGrantResult, title: String) {
        guard result.didGrant else { return }

        if result.didRankUp {
            rankUp = RankUpPresentation(rank: result.newRank, xpToNextRank: RankProgressService.shared.xpToNextRank)
            playSound(named: "tithuh-level-up-523624")
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }

        queueToast(amount: result.awardedAmount, title: title, isMajor: result.awardedAmount >= 20)
    }

    func dismissRankUp() {
        rankUp = nil
    }

    private func queueToast(amount: Int, title: String, isMajor: Bool) {
        pendingAmount += amount
        pendingTitle = title
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            await self?.flush(isMajor: isMajor)
        }
    }

    private func flush(isMajor: Bool) {
        guard pendingAmount > 0 else { return }
        toast = XPToast(amount: pendingAmount, title: pendingTitle, isMajor: isMajor)
        playSound(named: isMajor ? "universfield-level-up-05-326133" : "koiroylers-get-coin-351945")
        UIImpactFeedbackGenerator(style: isMajor ? .medium : .light).impactOccurred()

        pendingAmount = 0
        pendingTitle = "XP"

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            await MainActor.run { self?.toast = nil }
        }
    }

    private func playSound(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf", subdirectory: "Resources/SFX/Ranks")
            ?? Bundle.main.url(forResource: name, withExtension: "caf", subdirectory: "SFX/Ranks")
            ?? Bundle.main.url(forResource: name, withExtension: "caf", subdirectory: "Ranks")
            ?? Bundle.main.url(forResource: name, withExtension: "caf") else {
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 0.2
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("[XP] reward sound failed name=\(name) error=\(error.localizedDescription)")
        }
    }
}
