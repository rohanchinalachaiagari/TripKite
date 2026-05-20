import SwiftUI
import UIKit

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(
        settingsStore: SettingsStore,
        dataManagement: DataManagementService,
        notificationService: NotificationSchedulingService
    ) {
        _viewModel = StateObject(
            wrappedValue: SettingsViewModel(
                settingsStore: settingsStore,
                dataManagement: dataManagement,
                notificationService: notificationService
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TKBackground()
                Form {
                    defaultsSection
                    notificationsSection
                    aboutSection
                    dataSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .task { await viewModel.refreshAuthorizationStatus() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await viewModel.refreshAuthorizationStatus() }
                }
            }
            .alert(
                "Delete all TripKite data?",
                isPresented: $viewModel.pendingClearConfirmation
            ) {
                Button("Delete Everything", role: .destructive) {
                    Task { await viewModel.confirmClearAllData() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes every trip, itinerary item, attached document, and scheduled reminder. This cannot be undone.")
            }
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                ),
                presenting: viewModel.errorMessage
            ) { _ in
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: { message in
                Text(message)
            }
        }
    }

    // MARK: - Sections

    private var defaultsSection: some View {
        Section {
            Picker("Default reminder", selection: $viewModel.defaultReminderOption) {
                ForEach(ReminderOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
        } header: {
            Text("Defaults")
        } footer: {
            Text("New itinerary items start with this reminder option selected.")
        }
    }

    @ViewBuilder
    private var notificationsSection: some View {
        Section {
            HStack {
                Text("Status")
                Spacer()
                Text(authorizationStatusText)
                    .foregroundStyle(TKColors.textSecondary)
            }

            if shouldShowOpenSettings {
                Button {
                    openSystemSettings()
                } label: {
                    Label("Open Settings", systemImage: "arrow.up.right.square")
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text(notificationsFooter)
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(TKColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: TKSpacing.xs) {
                Text("Privacy")
                    .font(TKTypography.cardSubtitle)
                Text("TripKite stores your trips, itinerary items, reminders, and documents locally on this device. TripKite does not require an account, does not collect analytics, and does not send your personal travel data to a server. Documents you attach may be included in your standard iOS device backup if you have iCloud Backup enabled.")
                    .font(TKTypography.metadata)
                    .foregroundStyle(TKColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, TKSpacing.xs)

            Link(destination: URL(string: "mailto:sunronreddy@gmail.com")!) {
                Label("Contact Support", systemImage: "envelope")
            }
        } header: {
            Text("About")
        }
    }

    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.requestClearAllData()
            } label: {
                HStack {
                    Label("Clear All Data", systemImage: "trash")
                    Spacer()
                    if viewModel.isClearing {
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.isClearing)
        } header: {
            Text("Data")
        } footer: {
            Text("Permanently removes every trip, itinerary item, attached document, and scheduled reminder from this device.")
        }
    }

    // MARK: - Helpers

    private var authorizationStatusText: String {
        switch viewModel.authorizationStatus {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .notDetermined: return "Not Requested"
        case .provisional: return "Provisional"
        }
    }

    private var shouldShowOpenSettings: Bool {
        switch viewModel.authorizationStatus {
        case .denied, .notDetermined: return true
        case .authorized, .provisional: return false
        }
    }

    private var notificationsFooter: String {
        switch viewModel.authorizationStatus {
        case .authorized, .provisional:
            return "Reminders for itinerary items will appear as notifications."
        case .denied:
            return "Reminders cannot be delivered until you enable notifications for TripKite in Settings."
        case .notDetermined:
            return "TripKite will request permission the first time you set a reminder."
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#if DEBUG
#Preview {
    SettingsView(
        settingsStore: UserDefaultsSettingsStore(defaults: UserDefaults(suiteName: "TripKite-Preview")!),
        dataManagement: PreviewDataManagementService(),
        notificationService: UserNotificationSchedulingService()
    )
}

private final class PreviewDataManagementService: DataManagementService, @unchecked Sendable {
    func clearAllData() async throws {}
}
#endif
