import Foundation
import Combine

final class OnboardingViewModel: ObservableObject {
    @Published private(set) var state = OnboardingState()
    @Published var navigationPath: [OnboardingStep] = []
    @Published var snoozesPerMorning: Int = 3
    @Published var userAge: Int = 25
    @Published var animationTrigger: Bool = false

    private let permissionService: NotificationPermissionService
    private let wallpaperLoader: WallpaperCatalogLoader
    private let fileStorage: FileStorageService
    private let recoveryKey = "alarmo.onboarding.recoveryStepRaw"

    init(permissionService: NotificationPermissionService = SystemNotificationPermissionService(),
         wallpaperLoader: WallpaperCatalogLoader = BundleWallpaperCatalogLoader(),
         fileStorage: FileStorageService = LocalFileStorageService()) {
        self.permissionService = permissionService
        self.wallpaperLoader = wallpaperLoader
        self.fileStorage = fileStorage
        resetRecoveryStep()
        
        $navigationPath
            .dropFirst()
            .sink { [weak self] newPath in
                guard let self = self else { return }
                let newStep = newPath.last ?? .intro
                if newStep != self.state.currentStep {
                    self.state.currentStep = newStep
                    UserDefaults.standard.set(newStep.rawValue, forKey: self.recoveryKey)
                }
            }
            .store(in: &cancellables)
    }

    private func resetRecoveryStep() {
        UserDefaults.standard.removeObject(forKey: recoveryKey)
        state.currentStep = .intro
        navigationPath = []
    }

    var selectedHour: Int {
        get { state.selectedHour }
        set { state.selectedHour = newValue }
    }

    var firstName: String {
        state.firstName
    }

    var displayFirstName: String {
        let trimmed = state.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "there" : trimmed
    }

    var selectedMinute: Int {
        get { state.selectedMinute }
        set { state.selectedMinute = newValue }
    }

    var selectedSecond: Int {
        get { state.selectedSecond }
        set { state.selectedSecond = newValue }
    }

    var selectedTimeString: String {
        TimeFormatters.formattedTime(hour: selectedHour, minute: selectedMinute)
    }

    var canProceedWallpaper: Bool {
        true
    }

    var volumePercentText: String {
        "\(Int(state.selectedVolume * 100))%"
    }

    func nextStep() {
        guard let next = state.currentStep.next() else { return }
        setStep(next)
    }

    func setStep(_ step: OnboardingStep) {
        state.currentStep = step
        UserDefaults.standard.set(step.rawValue, forKey: recoveryKey)
    }

    func setFirstName(_ name: String) {
        state.firstName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func startSetupFlowFromIntroCTA() {
        state.currentStep = .namePrompt
        navigationPath = [.namePrompt]
        UserDefaults.standard.set(OnboardingStep.namePrompt.rawValue, forKey: recoveryKey)
    }

    var snoozeCalculator: SnoozeCalculator {
        SnoozeCalculator(snoozesPerMorning: snoozesPerMorning, userAge: userAge)
    }

    func persistSnoozeOnboardingInputs() {
        UserDefaults.standard.set(snoozesPerMorning, forKey: "onboarding_snoozeCount")
        UserDefaults.standard.set(userAge, forKey: "onboarding_age")
    }

    private var cancellables = Set<AnyCancellable>()

    func loadWallpapers() {
        // Initial load (bundled)
        reloadWallpaperList()
        
        // Listen for remote updates
        AssetManager.shared.$remoteWallpapers
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reloadWallpaperList() }
            .store(in: &cancellables)
            
        // Trigger fetch if needed
        Task { await AssetManager.shared.fetchCatalog() }
    }
    
    private func reloadWallpaperList() {
        do {
            state.wallpaperCategories = try wallpaperLoader.loadCategories()
        } catch {
            state.wallpaperCategories = []
        }
    }

    func selectWallpaper(_ item: WallpaperItem) {
        // If remote, ensure download first
        if case .remote(let url) = item.source {
            // Already cached?
            // The item.url might already be local if loader found it.
            if url.isFileURL {
                state.selectedWallpaper = WallpaperRef(id: item.id, title: item.title, source: .userPhoto(url: url))
            } else {
                // Determine filename (e.g. from ID or URL path)
                // We'll use ID + extension or just last path component of a known structure
                // Ideally item.id or metadata has filename.
                // But here item doesn't expose filename directly, only via ID hack.
                // Let's rely on lastPathComponent of URL for simplicity, or make up a consistent name.
                let filename = url.lastPathComponent 
                
                Task {
                    do {
                        let localURL = try await AssetManager.shared.downloadAsset(from: url, filename: filename)
                        await MainActor.run {
                            self.state.selectedWallpaper = WallpaperRef(
                                id: item.id,
                                title: item.title,
                                source: .userPhoto(url: localURL)
                            )
                        }
                    } catch {
                        print("Failed to download wallpaper: \(error)")
                    }
                }
                
                // Set temporary remote ref so UI updates selection border immediately (AsyncImage handles display)
                state.selectedWallpaper = WallpaperRef(id: item.id, title: item.title, source: item.source)
            }
        } else {
            state.selectedWallpaper = WallpaperRef(id: item.id, title: item.title, source: item.source)
        }
    }

    func setSelectedSound(_ sound: SoundAsset) {
        state.selectedSoundId = sound.id
        state.selectedSoundURL = sound.fileURL
        state.selectedSoundName = sound.title
        
        // If remote, trigger download for offline reliability
        if !sound.fileURL.isFileURL {
            let filename = sound.fileURL.lastPathComponent
            Task {
                do {
                    let localURL = try await AssetManager.shared.downloadAsset(from: sound.fileURL, filename: filename)
                    await MainActor.run {
                        // If this is still the selected sound, update to local URL
                        if self.state.selectedSoundId == sound.id {
                            self.state.selectedSoundURL = localURL
                            print("✅ Sound downloaded and updated to local: \(filename)")
                        }
                    }
                } catch {
                    print("❌ Failed to download sound: \(error)")
                }
            }
        }
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

    func setDailyMotivation(_ enabled: Bool) {
        state.dailyMotivationEnabled = enabled
    }

    var quoteCategoryOptions: [MotivationQuoteCategory] {
        MotivationQuoteCategory.allCases
    }

    func isQuoteCategorySelected(_ categoryId: String) -> Bool {
        state.selectedQuoteCategoryIDs.contains(categoryId)
    }

    func toggleQuoteCategory(_ categoryId: String) {
        if categoryId == MotivationQuoteCategory.allSelectionID {
            state.selectedQuoteCategoryIDs = [MotivationQuoteCategory.allSelectionID]
            return
        }

        state.selectedQuoteCategoryIDs.remove(MotivationQuoteCategory.allSelectionID)
        if state.selectedQuoteCategoryIDs.contains(categoryId) {
            state.selectedQuoteCategoryIDs.remove(categoryId)
        } else {
            state.selectedQuoteCategoryIDs.insert(categoryId)
        }

        if state.selectedQuoteCategoryIDs.isEmpty {
            state.selectedQuoteCategoryIDs = [MotivationQuoteCategory.allSelectionID]
        }
    }

    var selectedQuotePreview: MotivationQuote? {
        let quotes = MotivationQuotes.filteredQuotes(for: state.selectedQuoteCategoryIDs)
        guard !quotes.isEmpty else { return nil }
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return quotes[(dayOfYear - 1) % quotes.count]
    }

    func completeOnboarding() {
        state.onboardingCompleted = true
        UserDefaults.standard.removeObject(forKey: recoveryKey)
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

    @MainActor
    func saveUserPhoto(data: Data, fileExtension: String) {
        do {
            let url = try fileStorage.saveImageData(data, fileExtension: fileExtension)
            state.selectedWallpaper = WallpaperRef(
                id: WallpaperSelectionID.makeUserPhotoID(from: url),
                title: "My Photo",
                source: .userPhoto(url: url)
            )
        } catch {
            print("Failed to save selected wallpaper photo: \(error)")
            return
        }
    }
}
