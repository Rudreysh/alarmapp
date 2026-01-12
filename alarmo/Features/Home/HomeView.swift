import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @ObservedObject var alarmStore: AlarmStore
    @State private var showProPaywall = false
    @State private var proPaywallStartStep: ProPaywallStep = .intro
    @State private var showAddMenu = false
    @State private var showCreateAlarm = false

    init(viewModel: HomeViewModel, alarmStore: AlarmStore) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.alarmStore = alarmStore
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Colors.bgSecondary, Colors.bgPrimary], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.l) {
                    HStack {
                        Spacer()
                        Button(action: {}) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Colors.textSecondary)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(Text("More options"))
                    }
                    .padding(.top, Spacing.s)

                    HStack {
                        Button(action: {
                            proPaywallStartStep = .intro
                            showProPaywall = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Colors.accentRed)
                                Text("PRO Free Trial")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Colors.textPrimary)
                            }
                            .padding(.horizontal, Spacing.m)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Colors.accentRed.opacity(0.7), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PressedScaleButtonStyle())

                        Spacer()
                    }


                    PromoCard(
                        iconSystemName: "moon.zzz.fill",
                        title: "Track your snoring",
                        subtitle: "Half of people snored last night"
                    ) {}

                    if !alarmStore.alarms.isEmpty {
                        Text("Ring in 19hrs 9min  >")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)

                        LazyVStack(spacing: Spacing.m) {
                            ForEach(alarmStore.alarms) { alarm in
                                SwipeableAlarmRow(
                                    onDelete: { alarmStore.remove(id: alarm.id) }
                                ) {
                                    AlarmCardView(
                                        time: alarm.timeString,
                                        repeatMask: alarm.repeatMask,
                                        isEnabled: Binding(
                                            get: { alarm.enabled },
                                            set: { alarmStore.toggleEnabled(id: alarm.id, enabled: $0) }
                                        )
                                    )
                                }
                            }
                        }
                    } else {
                        Text("No upcoming alarms")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                            .padding(.top, Spacing.s)
                    }

                    Spacer(minLength: 120)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, AppConstants.tabBarHeight + Spacing.xl)
                }

                if alarmStore.alarms.isEmpty {
                    Text("No alarm set")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Colors.textTertiary)
                        .frame(maxHeight: .infinity, alignment: .center)
                }

                VStack {
                    Spacer()
                    Button(action: viewModel.tapRemoveAds) {
                        HStack(spacing: 8) {
                            Image(systemName: "nosign")
                                .foregroundColor(Colors.textSecondary)
                            Text("Remove all ads")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Colors.textSecondary)
                        }
                        .padding(.vertical, 10)
                    }
                    .accessibilityLabel(Text("Remove all ads"))
                    .padding(.bottom, AppConstants.tabBarHeight + Spacing.s)
                }
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAddMenu.toggle()
                        }
                    }) {
                        Image(systemName: showAddMenu ? "xmark" : "plus")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                            .frame(width: 62, height: 62)
                            .background(Colors.accentRed)
                            .clipShape(Circle())
                            .appShadow(Shadows.card)
                    }
                    .accessibilityLabel(Text("Add alarm"))
                    .padding(.trailing, Spacing.l)
                    .padding(.bottom, AppConstants.tabBarHeight + Spacing.l)
                }
            }

            if showAddMenu {
                Colors.bgPrimary.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAddMenu = false
                        }
                    }

                FloatingAddMenu(
                    onSelectHabit: {
                        showAddMenu = false
                    },
                    onSelectQuick: {
                        showAddMenu = false
                    },
                    onSelectAlarm: {
                        openCreateAlarm()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if viewModel.showCelebration {
                CelebrationOverlayView {
                    viewModel.celebrationDidFinish()
                }
            }

            if viewModel.showDiscountPaywall {
                DiscountPaywallView(
                    preferences: viewModel.preferences,
                    onClose: viewModel.dismissPaywall,
                    onApply: viewModel.dismissPaywall,
                    onGetOffer: {
                        viewModel.dismissPaywall()
                        proPaywallStartStep = .planSelection
                        showProPaywall = true
                    }
                )
            }

            if showProPaywall {
                ProPaywallFlowView(startStep: proPaywallStartStep) {
                    showProPaywall = false
                }
                .transition(.move(edge: .bottom))
            }
        }
        .onAppear { viewModel.onAppear() }
        .onReceive(alarmStore.$alarms) { alarms in
            viewModel.preferences.hasAnyAlarm = !alarms.isEmpty
        }
        .fullScreenCover(isPresented: $showCreateAlarm) {
            CreateWakeUpAlarmView(
                alarmStore: alarmStore,
                onClose: { showCreateAlarm = false }
            )
        }
    }

    private func openCreateAlarm() {
        showAddMenu = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showCreateAlarm = true
        }
    }
}

private struct AlarmCardView: View {
    let time: String
    let repeatMask: Int
    @Binding var isEnabled: Bool

    private let weekdays: [String] = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(0..<weekdays.count, id: \.self) { index in
                        Text(weekdays[index])
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isDayEnabled(index: index) ? Colors.accentTeal : Colors.textTertiary)
                    }
                }
                Text(time)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
            }
            Spacer()
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Colors.accentRed))
        }
        .padding(Spacing.m)
        .background(Colors.cardSurface)
        .cornerRadius(22)
    }

    private func isDayEnabled(index: Int) -> Bool {
        let bit = 1 << index
        return (repeatMask & bit) != 0
    }
}

private struct SwipeableAlarmRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0

    private let maxOffset: CGFloat = -86
    private let revealThreshold: CGFloat = -50

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: onDelete) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.trailing, 4)

            content()
                .offset(x: offset + dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .updating($dragOffset) { value, state, _ in
                            if value.translation.width < 0 || offset < 0 {
                                state = value.translation.width
                            }
                        }
                        .onEnded { value in
                            let total = offset + value.translation.width
                            if total < revealThreshold {
                                offset = maxOffset
                            } else {
                                offset = 0
                            }
                        }
                )
                .onTapGesture {
                    if offset != 0 {
                        offset = 0
                    }
                }
        }
        .animation(.easeInOut(duration: 0.18), value: offset)
    }
}
