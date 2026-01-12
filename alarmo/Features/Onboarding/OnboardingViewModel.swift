import Foundation
import Combine

final class OnboardingViewModel: ObservableObject {
    @Published private(set) var state = OnboardingState()

    private let permissionService: NotificationPermissionService
    private let wallpaperLoader: WallpaperCatalogLoader
    private let fileStorage: FileStorageService

    init(permissionService: NotificationPermissionService = SystemNotificationPermissionService(),
         wallpaperLoader: WallpaperCatalogLoader = BundleWallpaperCatalogLoader(),
         fileStorage: FileStorageService = LocalFileStorageService()) {
        self.permissionService = permissionService
        self.wallpaperLoader = wallpaperLoader
        self.fileStorage = fileStorage
    }

    var selectedHour: Int {
        get { state.selectedHour }
        set { state.selectedHour = newValue }
    }

    var selectedMinute: Int {
        get { state.selectedMinute }
        set { state.selectedMinute = newValue }
    }

    var selectedTimeString: String {
        TimeFormatters.formattedTime(hour: selectedHour, minute: selectedMinute)
    }

    var canProceedWallpaper: Bool {
        state.selectedWallpaper != nil
    }

    var volumePercentText: String {
        "\(Int(state.selectedVolume * 100))%"
    }

    func nextStep() {
        guard let next = state.currentStep.next() else { return }
        state.currentStep = next
    }

    func setStep(_ step: OnboardingStep) {
        state.currentStep = step
    }

    func loadWallpapers() {
        do {
            state.wallpaperCategories = try wallpaperLoader.loadCategories()
        } catch {
            state.wallpaperCategories = []
        }
    }

    func selectWallpaper(_ item: WallpaperItem) {
        state.selectedWallpaper = WallpaperRef(id: item.id, title: item.title, source: item.source)
    }

    func setSelectedSound(_ sound: SoundAsset) {
        state.selectedSoundId = sound.id
        state.selectedSoundURL = sound.fileURL
    }

    func setVolume(_ volume: Float) {
        state.selectedVolume = volume
    }

    func setGentleWakeUp(_ enabled: Bool) {
        state.gentleWakeUpEnabled = enabled
    }

    func setMission(_ mission: WakeUpMissionType) {
        state.missionType = mission
    }

    func completeOnboarding() {
        state.onboardingCompleted = true
    }

    @MainActor
    func requestNotificationPermissionAndAdvance() async {
        let alreadyAuthorized = await permissionService.isAuthorized()
        if alreadyAuthorized {
            state.notificationsAuthorized = true
            nextStep()
            return
        }
        let granted = await permissionService.requestAuthorization()
        state.notificationsAuthorized = granted
        nextStep()
    }

    func saveUserPhoto(data: Data, fileExtension: String) {
        do {
            let url = try fileStorage.saveImageData(data, fileExtension: fileExtension)
            state.selectedWallpaper = WallpaperRef(
                id: url.lastPathComponent,
                title: "My Photo",
                source: .userPhoto(url: url)
            )
        } catch {
            return
        }
    }
}
