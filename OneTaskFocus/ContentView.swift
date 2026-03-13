//
//  ContentView.swift
//  OneTaskFocus
//
//  Created by Tam Le on 3/12/26.
//

import SwiftUI
import SwiftData
import UserNotifications
#if os(iOS)
import UIKit
#endif

private enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

private enum AccentOption: String, CaseIterable, Identifiable {
    case blue
    case red
    case green
    case orange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blue:
            return "Blue"
        case .red:
            return "Red"
        case .green:
            return "Forest"
        case .orange:
            return "Warm Orange"
        }
    }

    var color: Color {
        switch self {
        case .blue:
            return Color(red: 0.23, green: 0.51, blue: 0.96)
        case .red:
            return Color(red: 0.86, green: 0.24, blue: 0.24)
        case .green:
            return Color(red: 0.18, green: 0.55, blue: 0.39)
        case .orange:
            return Color(red: 0.91, green: 0.47, blue: 0.22)
        }
    }
}

private enum AppBackgroundStyle {
    static let blueRedGradient = LinearGradient(
        colors: [
            Color(red: 0.17, green: 0.44, blue: 0.96).opacity(0.20),
            Color(uiColor: .systemBackground),
            Color(red: 0.86, green: 0.24, blue: 0.24).opacity(0.18)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private struct ActiveSession {
    var taskTitle: String
    var sessionNote: String
    var totalDuration: Int
    var remainingDuration: Int
    var startedAt: Date
    var endDate: Date?
    var isPaused: Bool
}

private struct CompletedSession {
    var taskTitle: String
    var duration: Int
}

struct AppRootView: View {
    @State private var showsSplash = true

    var body: some View {
        ZStack {
            ContentView()

            if showsSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeInOut(duration: 0.35)) {
                showsSplash = false
            }
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FocusSession.endedAt, order: .reverse) private var sessions: [FocusSession]

    @AppStorage("defaultDuration") private var defaultDuration = 25
    @AppStorage("appearance") private var appearanceRawValue = AppAppearance.system.rawValue
    @AppStorage("accent") private var accentRawValue = AccentOption.blue.rawValue
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("minimalMode") private var minimalMode = false

    var body: some View {
        TabView {
            FocusView(
                defaultDuration: defaultDuration,
                notificationsEnabled: notificationsEnabled,
                soundEnabled: soundEnabled,
                hapticsEnabled: hapticsEnabled,
                accent: selectedAccent,
                onSaveSession: saveSession
            )
            .tabItem {
                Label("Focus", systemImage: "timer")
            }

            HistoryView(
                sessions: sessions,
                accent: selectedAccent,
                minimalMode: minimalMode
            )
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }

            SettingsView(
                defaultDuration: $defaultDuration,
                appearance: Binding(
                    get: { selectedAppearance },
                    set: { appearanceRawValue = $0.rawValue }
                ),
                accent: Binding(
                    get: { selectedAccent },
                    set: { accentRawValue = $0.rawValue }
                ),
                notificationsEnabled: $notificationsEnabled,
                soundEnabled: $soundEnabled,
                hapticsEnabled: $hapticsEnabled,
                minimalMode: $minimalMode
            )
            .tabItem {
                Label("Settings", systemImage: "slider.horizontal.3")
            }
        }
        .tint(selectedAccent.color)
        .preferredColorScheme(selectedAppearance.colorScheme)
    }

    private var selectedAppearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }

    private var selectedAccent: AccentOption {
        AccentOption(rawValue: accentRawValue) ?? .blue
    }

    private func saveSession(_ session: FocusSession) {
        modelContext.insert(session)
    }
}

private struct SplashScreenView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.17, green: 0.44, blue: 0.96),
                    Color(red: 0.86, green: 0.24, blue: 0.24)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.20), lineWidth: 18)
                        .frame(width: 156, height: 156)

                    Circle()
                        .trim(from: 0.15, to: 0.88)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 156, height: 156)

                    Text("1")
                        .font(.system(size: 82, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 8) {
                    Text("One-Task Focus")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Do one thing well.")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.88))
                }
            }
            .padding(24)
        }
    }
}

private struct FocusView: View {
    let defaultDuration: Int
    let notificationsEnabled: Bool
    let soundEnabled: Bool
    let hapticsEnabled: Bool
    let accent: AccentOption
    let onSaveSession: (FocusSession) -> Void

    @State private var taskTitle = ""
    @State private var sessionNote = ""
    @State private var selectedDuration = 25
    @State private var activeSession: ActiveSession?
    @State private var completedSession: CompletedSession?
    @State private var timerTask: Task<Void, Never>?

    private let durationOptions = [15, 25, 45, 60]

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        switch (activeSession, completedSession) {
                        case let (session?, _):
                            ActiveSessionView(
                                session: session,
                                accent: accent,
                                onPauseResume: togglePause,
                                onEnd: endSession
                            )
                        case let (nil, completed?):
                            SessionCompleteView(
                                session: completed,
                                accent: accent,
                                onStartAnother: restartCompletedTask,
                                onTakeBreak: startBreak,
                                onDone: resetAfterCompletion
                            )
                        default:
                            IdleFocusView(
                                taskTitle: $taskTitle,
                                sessionNote: $sessionNote,
                                selectedDuration: $selectedDuration,
                                durationOptions: durationOptions,
                                accent: accent,
                                onStart: startSession
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle(activeSession == nil ? "One-Task Focus" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(activeSession == nil ? .visible : .hidden, for: .tabBar)
            .onAppear {
                if activeSession == nil && completedSession == nil {
                    selectedDuration = defaultDuration
                }
            }
            .onChange(of: defaultDuration) { _, newValue in
                if activeSession == nil && completedSession == nil {
                    selectedDuration = newValue
                }
            }
            .onDisappear {
                timerTask?.cancel()
            }
        }
    }

    private var backgroundGradient: LinearGradient {
        AppBackgroundStyle.blueRedGradient
    }

    private func startSession() {
        let trimmedTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let duration = selectedDuration * 60
        let startedAt = Date()
        let endDate = startedAt.addingTimeInterval(TimeInterval(duration))

        completedSession = nil
        activeSession = ActiveSession(
            taskTitle: trimmedTitle,
            sessionNote: sessionNote.trimmingCharacters(in: .whitespacesAndNewlines),
            totalDuration: duration,
            remainingDuration: duration,
            startedAt: startedAt,
            endDate: endDate,
            isPaused: false
        )

        triggerHaptic(.success)
        scheduleNotification(for: trimmedTitle, after: duration)
        startTimerLoop()
    }

    private func togglePause() {
        guard var session = activeSession else { return }

        if session.isPaused {
            let endDate = Date().addingTimeInterval(TimeInterval(session.remainingDuration))
            session.isPaused = false
            session.endDate = endDate
            activeSession = session
            scheduleNotification(for: session.taskTitle, after: session.remainingDuration)
            startTimerLoop()
        } else {
            guard let endDate = session.endDate else { return }
            session.remainingDuration = max(Int(ceil(endDate.timeIntervalSinceNow)), 0)
            session.isPaused = true
            session.endDate = nil
            activeSession = session
            timerTask?.cancel()
            NotificationCoordinator.shared.cancelPending()
        }

        triggerHaptic(.light)
    }

    private func endSession() {
        timerTask?.cancel()
        NotificationCoordinator.shared.cancelPending()
        activeSession = nil
        triggerHaptic(.warning)
    }

    private func completeSession() {
        guard let session = activeSession else { return }

        timerTask?.cancel()
        NotificationCoordinator.shared.cancelPending()
        onSaveSession(
            FocusSession(
                taskTitle: session.taskTitle,
                sessionNote: session.sessionNote,
                duration: session.totalDuration,
                startedAt: session.startedAt,
                endedAt: Date()
            )
        )

        activeSession = nil
        completedSession = CompletedSession(
            taskTitle: session.taskTitle,
            duration: session.totalDuration
        )

        triggerHaptic(.success)
    }

    private func restartCompletedTask() {
        guard let completedSession else { return }
        taskTitle = completedSession.taskTitle
        selectedDuration = completedSession.duration / 60
        self.completedSession = nil
        startSession()
    }

    private func startBreak() {
        completedSession = nil
        taskTitle = "Take a break"
        sessionNote = "Reset briefly and come back clear."
        selectedDuration = 5
        startSession()
    }

    private func resetAfterCompletion() {
        completedSession = nil
        taskTitle = ""
        sessionNote = ""
        selectedDuration = defaultDuration
    }

    private func startTimerLoop() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                guard let endDate = await MainActor.run(body: { activeSession?.endDate }) else {
                    return
                }

                let remaining = max(Int(ceil(endDate.timeIntervalSinceNow)), 0)

                await MainActor.run {
                    activeSession?.remainingDuration = remaining
                }

                if remaining <= 0 {
                    await MainActor.run {
                        completeSession()
                    }
                    return
                }

                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func scheduleNotification(for taskTitle: String, after duration: Int) {
        guard notificationsEnabled else { return }

        Task {
            await NotificationCoordinator.shared.scheduleFocusEndedNotification(
                taskTitle: taskTitle,
                timeInterval: duration,
                playSound: soundEnabled
            )
        }
    }

    private func triggerHaptic(_ type: HapticType) {
        guard hapticsEnabled else { return }
        Haptics.play(type)
    }
}

private struct IdleFocusView: View {
    @Binding var taskTitle: String
    @Binding var sessionNote: String
    @Binding var selectedDuration: Int

    let durationOptions: [Int]
    let accent: AccentOption
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What are you focusing on?")
                    .font(.largeTitle.weight(.bold))

                Text("Do one thing well.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 16) {
                TextField("Write project update", text: $taskTitle)
                    .font(.title3.weight(.semibold))
                    .textInputAutocapitalization(.sentences)

                TextField("Optional note", text: $sessionNote, axis: .vertical)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(2...4)
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

            VStack(spacing: 20) {
                Text(timeString(from: selectedDuration * 60))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)

                HStack(spacing: 12) {
                    ForEach(durationOptions, id: \.self) { duration in
                        Button {
                            selectedDuration = duration
                        } label: {
                            Text("\(duration)")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(selectedDuration == duration ? accent.color : Color(uiColor: .secondarySystemBackground))
                                )
                                .foregroundStyle(selectedDuration == duration ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color(uiColor: .systemBackground).opacity(0.88))
            )

            Button(action: onStart) {
                Text("Start Focus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(accent.color, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)

            Text("One task. One session.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct ActiveSessionView: View {
    let session: ActiveSession
    let accent: AccentOption
    let onPauseResume: () -> Void
    let onEnd: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Text(session.taskTitle)
                    .font(.title.weight(.semibold))
                    .multilineTextAlignment(.center)

                if !session.sessionNote.isEmpty {
                    Text(session.sessionNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 24)

            ZStack {
                Circle()
                    .stroke(accent.color.opacity(0.15), lineWidth: 16)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(accent.color, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 8) {
                    Text(timeString(from: session.remainingDuration))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Text(session.isPaused ? "Paused" : "Stay with this until the timer ends.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .frame(width: 280, height: 280)
            .padding(.vertical, 12)

            HStack(spacing: 14) {
                Button(action: onPauseResume) {
                    Text(session.isPaused ? "Resume" : "Pause")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color(uiColor: .systemBackground).opacity(0.92))
                        )
                }
                .buttonStyle(.plain)

                Button(action: onEnd) {
                    Text("End")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.red.opacity(0.14))
                        )
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
    }

    private var progress: Double {
        guard session.totalDuration > 0 else { return 0 }
        let elapsed = session.totalDuration - session.remainingDuration
        return min(max(Double(elapsed) / Double(session.totalDuration), 0), 1)
    }
}

private struct SessionCompleteView: View {
    let session: CompletedSession
    let accent: AccentOption
    let onStartAnother: () -> Void
    let onTakeBreak: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(accent.color)

            VStack(spacing: 10) {
                Text("Session complete")
                    .font(.largeTitle.weight(.bold))

                Text(session.taskTitle)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text("\(session.duration / 60) minutes finished")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                Button(action: onStartAnother) {
                    Text("Start Another Session")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(accent.color, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button(action: onTakeBreak) {
                    Text("Take a Break")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color(uiColor: .systemBackground).opacity(0.92))
                        )
                }
                .buttonStyle(.plain)

                Button("Done", action: onDone)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
    }
}

private struct HistoryView: View {
    let sessions: [FocusSession]
    let accent: AccentOption
    let minimalMode: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.17, green: 0.44, blue: 0.96).opacity(0.16),
                        Color(uiColor: .systemBackground),
                        Color(red: 0.86, green: 0.24, blue: 0.24).opacity(0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        if !minimalMode {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 2), spacing: 14) {
                                StatCard(title: "Today", value: formattedDuration(historyStats.totalToday), accent: accent)
                                StatCard(title: "Sessions", value: "\(historyStats.sessionsToday)", accent: accent)
                                StatCard(title: "Streak", value: "\(historyStats.currentStreak) days", accent: accent)
                                StatCard(title: "This Week", value: formattedDuration(historyStats.totalThisWeek), accent: accent)
                            }
                        }

                        if groupedSessions.isEmpty {
                            EmptyStateView(
                                title: "No focus sessions yet",
                                message: "Finish one session and it will appear here."
                            )
                        } else {
                            ForEach(groupedSessions) { group in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(group.title)
                                        .font(.title3.weight(.semibold))

                                    ForEach(group.sessions) { session in
                                        SessionRow(session: session)
                                    }
                                }
                                .padding(20)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("History")
        }
    }

    private var groupedSessions: [SessionGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.endedAt)
        }

        return grouped
            .keys
            .sorted(by: >)
            .map { day in
                SessionGroup(
                    date: day,
                    title: dayLabel(for: day, calendar: calendar),
                    sessions: grouped[day, default: []].sorted(by: { $0.endedAt > $1.endedAt })
                )
            }
    }

    private var historyStats: HistoryStats {
        HistoryStats(sessions: sessions)
    }
}

private struct SettingsView: View {
    @Binding var defaultDuration: Int
    @Binding var appearance: AppAppearance
    @Binding var accent: AccentOption
    @Binding var notificationsEnabled: Bool
    @Binding var soundEnabled: Bool
    @Binding var hapticsEnabled: Bool
    @Binding var minimalMode: Bool

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    settingsCard("Defaults") {
                        Picker("Default Timer", selection: $defaultDuration) {
                            Text("15 min").tag(15)
                            Text("25 min").tag(25)
                            Text("45 min").tag(45)
                            Text("60 min").tag(60)
                        }
                        .pickerStyle(.segmented)

                        Picker("Appearance", selection: $appearance) {
                            ForEach(AppAppearance.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }

                        Picker("Accent", selection: $accent) {
                            ForEach(AccentOption.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                    }

                    settingsCard("Feedback") {
                        Toggle("Notifications", isOn: $notificationsEnabled)
                        Toggle("Sound", isOn: $soundEnabled)
                        Toggle("Haptics", isOn: $hapticsEnabled)
                        Toggle("Minimal mode", isOn: $minimalMode)
                    }

                    settingsCard("Permission") {
                        Text(permissionCopy)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button("Enable Notifications") {
                            Task {
                                await NotificationCoordinator.shared.requestAuthorization()
                                await refreshAuthorizationStatus()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Settings")
            .task {
                await refreshAuthorizationStatus()
            }
        }
    }

    private var permissionCopy: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Notifications are ready for session end alerts."
        case .denied:
            return "Notifications are off. You can re-enable them from the system Settings app."
        case .notDetermined:
            return "Allow notifications so the timer can alert you when a focus session ends."
        @unknown default:
            return "Notification status is unavailable."
        }
    }

    private func refreshAuthorizationStatus() async {
        authorizationStatus = await NotificationCoordinator.shared.authorizationStatus()
    }

    @ViewBuilder
    private func settingsCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)

            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let accent: AccentOption

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.bold))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(accent.color.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct SessionRow: View {
    let session: FocusSession

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.primary.opacity(0.12))
                .frame(width: 10, height: 10)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.taskTitle)
                    .font(.headline)

                if !session.sessionNote.isEmpty {
                    Text(session.sessionNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(session.endedAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(formattedMinutes(session.duration))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct SessionGroup: Identifiable {
    let date: Date
    let title: String
    let sessions: [FocusSession]

    var id: Date { date }
}

private struct HistoryStats {
    let totalToday: Int
    let sessionsToday: Int
    let currentStreak: Int
    let totalThisWeek: Int

    init(sessions: [FocusSession]) {
        let calendar = Calendar.current
        let today = Date()

        totalToday = sessions
            .filter { calendar.isDateInToday($0.endedAt) }
            .reduce(0) { $0 + $1.duration }

        sessionsToday = sessions
            .filter { calendar.isDateInToday($0.endedAt) }
            .count

        totalThisWeek = sessions
            .filter { calendar.isDate($0.endedAt, equalTo: today, toGranularity: .weekOfYear) }
            .reduce(0) { $0 + $1.duration }

        let uniqueDays = Set(sessions.map { calendar.startOfDay(for: $0.endedAt) })
        var streak = 0
        var day = calendar.startOfDay(for: today)

        while uniqueDays.contains(day) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else {
                break
            }
            day = previousDay
        }

        currentStreak = streak
    }
}

private enum HapticType {
    case success
    case warning
    case light
}

private enum Haptics {
    static func play(_ type: HapticType) {
        #if os(iOS)
        switch type {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        #endif
    }
}

private actor NotificationCoordinator {
    static let shared = NotificationCoordinator()

    private let center = UNUserNotificationCenter.current()
    private let requestIdentifier = "one-task-focus-session-ended"

    func requestAuthorization() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func scheduleFocusEndedNotification(taskTitle: String, timeInterval: Int, playSound: Bool) async {
        let status = await authorizationStatus()

        if status == .notDetermined {
            await requestAuthorization()
        }

        let refreshedStatus = await authorizationStatus()
        guard refreshedStatus == .authorized || refreshedStatus == .provisional || refreshedStatus == .ephemeral else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Session complete"
        content.body = "\"\(taskTitle)\" is finished."
        if playSound {
            content.sound = .default
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(timeInterval, 1)), repeats: false)
        let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            return
        }
    }

    func cancelPending() {
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
    }
}

private func dayLabel(for date: Date, calendar: Calendar) -> String {
    if calendar.isDateInToday(date) {
        return "Today"
    }

    if calendar.isDateInYesterday(date) {
        return "Yesterday"
    }

    return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
}

private func timeString(from totalSeconds: Int) -> String {
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    return String(format: "%02d:%02d", minutes, seconds)
}

private func formattedMinutes(_ duration: Int) -> String {
    "\(duration / 60) min"
}

private func formattedDuration(_ duration: Int) -> String {
    let hours = duration / 3600
    let minutes = (duration % 3600) / 60

    if hours > 0 && minutes > 0 {
        return "\(hours)h \(minutes)m"
    }

    if hours > 0 {
        return "\(hours)h"
    }

    return "\(minutes)m"
}

#Preview {
    ContentView()
        .modelContainer(for: FocusSession.self, inMemory: true)
}
