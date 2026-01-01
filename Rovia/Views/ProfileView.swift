import SwiftUI

struct ProfileView: View {
    @State private var profile: UserProfile?
    @State private var targets: MacroTargets?
    @State private var isLoading = true
    @State private var showLogoutConfirmation = false
    @State private var isAppleHealthEnabled = false
    @State private var isRequestingHealthAccess = false
    @StateObject private var healthKit = HealthKitManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    Text("Profile")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Theme.Colors.foreground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 16)

                    // Profile Card
                    VStack(spacing: 16) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.muted)
                                .frame(width: 72, height: 72)

                            Text(avatarEmoji)
                                .font(.system(size: 32))
                        }

                        // Goal
                        Text(goalLabel)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.Colors.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.primary.opacity(0.1))
                            .cornerRadius(12)

                        // Stats
                        HStack(spacing: 0) {
                            ProfileStat(value: "\(profile?.age ?? 27)", label: "Age")
                            ProfileStat(value: "\(profile?.heightFt ?? 5)'\(profile?.heightIn ?? 10)\"", label: "Height")
                            ProfileStat(value: "\(profile?.weightLb ?? 175)", label: "lbs")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .cardStyle()

                    // Daily Targets
                    SectionView(title: "Daily Targets") {
                        VStack(spacing: 12) {
                            HStack {
                                TargetItem(value: "\(targets?.calories ?? 2000)", label: "Calories", color: Theme.Colors.calories)
                                TargetItem(value: "\(targets?.protein ?? 150)g", label: "Protein", color: Theme.Colors.protein)
                            }
                            HStack {
                                TargetItem(value: "\(targets?.carbs ?? 250)g", label: "Carbs", color: Theme.Colors.carbs)
                                TargetItem(value: "\(targets?.fat ?? 70)g", label: "Fat", color: Theme.Colors.fat)
                            }
                        }
                        .padding(16)
                        .cardStyle()
                    }

                    // Activity
                    SectionView(title: "Activity") {
                        VStack(spacing: 0) {
                            ActivityRow(label: "Lifting Days", value: "\(profile?.liftingDays ?? 4) days/week")
                            Divider().background(Theme.Colors.border.opacity(0.5))
                            ActivityRow(label: "Activity Level", value: activityLabel)
                        }
                        .cardStyle()
                    }

                    // Dietary Constraints
                    if let constraints = profile?.constraints, !constraints.isEmpty {
                        SectionView(title: "Dietary Constraints") {
                            FlowLayout(spacing: 8) {
                                ForEach(constraints, id: \.self) { constraint in
                                    Text(constraint.capitalized)
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.Colors.foreground)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Theme.Colors.muted.opacity(0.5))
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }

                    // Apple Health Integration
                    SectionView(title: "Health Integration") {
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(.red)
                                        Text("Apple Health")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Theme.Colors.foreground)
                                    }
                                    Text("Sync activity & sleep for dynamic targets")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.Colors.mutedForeground)
                                }

                                Spacer()

                                if isRequestingHealthAccess {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Toggle("", isOn: $isAppleHealthEnabled)
                                        .labelsHidden()
                                        .tint(Theme.Colors.primary)
                                        .onChange(of: isAppleHealthEnabled) { _, newValue in
                                            Task {
                                                await toggleAppleHealth(enabled: newValue)
                                            }
                                        }
                                }
                            }
                            .padding(14)

                            if isAppleHealthEnabled {
                                Divider().background(Theme.Colors.border.opacity(0.5))
                                HStack {
                                    Text("Last Sync")
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.Colors.mutedForeground)
                                    Spacer()
                                    if let lastSync = healthKit.lastSyncTime {
                                        Text(lastSync, style: .relative)
                                            .font(.system(size: 13))
                                            .foregroundColor(Theme.Colors.foreground)
                                    } else {
                                        Text("Not synced yet")
                                            .font(.system(size: 13))
                                            .foregroundColor(Theme.Colors.mutedForeground)
                                    }
                                }
                                .padding(14)

                                Divider().background(Theme.Colors.border.opacity(0.5))
                                Button {
                                    Task {
                                        try? await healthKit.syncToBackend()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 12))
                                        Text("Sync Now")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundColor(Theme.Colors.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(14)
                                }
                            }
                        }
                        .cardStyle()

                        // Pro badge
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            Text("Pro Feature")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.mutedForeground)
                        }
                        .padding(.top, 4)
                    }

                    // Settings
                    SectionView(title: "Settings") {
                        VStack(spacing: 0) {
                            SettingsRow(label: "Contact Support", action: contactSupport)
                            Divider().background(Theme.Colors.border.opacity(0.5))
                            SettingsRow(label: "Privacy Policy", action: openPrivacy)
                            Divider().background(Theme.Colors.border.opacity(0.5))
                            SettingsRow(label: "Sign Out", isDestructive: true) {
                                showLogoutConfirmation = true
                            }
                        }
                        .cardStyle()
                    }

                    // Version
                    Text("Rovia v1.0.0")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.mutedForeground)
                        .padding(.top, 16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Theme.Colors.background)
        }
        .confirmationDialog("Sign out of Rovia?", isPresented: $showLogoutConfirmation) {
            Button("Sign Out", role: .destructive) {
                // TODO: Implement sign out
            }
        }
        .task {
            await loadProfile()
        }
    }

    private var avatarEmoji: String {
        switch profile?.sex {
        case "male": return "👨"
        case "female": return "👩"
        default: return "🧑"
        }
    }

    private var goalLabel: String {
        switch profile?.goal {
        case "recomp": return "Recomposition"
        case "lean_bulk": return "Lean Bulk"
        case "cut": return "Cut"
        default: return profile?.goal.capitalized ?? "Recomposition"
        }
    }

    private var activityLabel: String {
        switch profile?.stepsLevel {
        case "low": return "Low"
        case "med": return "Medium"
        case "high": return "High"
        default: return "Medium"
        }
    }

    private func loadProfile() async {
        do {
            async let profileTask = APIService.shared.fetchProfile()
            async let targetsTask = APIService.shared.fetchDailyTargets()

            profile = try await profileTask
            targets = try await targetsTask
        } catch {
            print("Failed to load profile: \(error)")
        }
        isLoading = false
    }

    private func contactSupport() {
        if let url = URL(string: "mailto:support@rovia.app") {
            UIApplication.shared.open(url)
        }
    }

    private func openPrivacy() {
        if let url = URL(string: "https://rovia.app/privacy") {
            UIApplication.shared.open(url)
        }
    }

    private func toggleAppleHealth(enabled: Bool) async {
        if enabled {
            isRequestingHealthAccess = true
            do {
                let authorized = try await healthKit.requestAuthorization()
                if authorized {
                    // Initial sync
                    try await healthKit.fetchTodayMetrics()
                    try await healthKit.syncToBackend()
                } else {
                    // User denied access
                    isAppleHealthEnabled = false
                }
            } catch {
                print("Failed to enable Apple Health: \(error)")
                isAppleHealthEnabled = false
            }
            isRequestingHealthAccess = false
        }
        // Note: Disabling just stops syncing - we don't revoke HealthKit access
    }
}

// MARK: - Supporting Views
struct SectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.mutedForeground)

            content
        }
    }
}

struct ProfileStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.Colors.foreground)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.mutedForeground)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TargetItem: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.mutedForeground)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ActivityRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Theme.Colors.mutedForeground)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.foreground)
        }
        .padding(14)
    }
}

struct SettingsRow: View {
    let label: String
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(isDestructive ? Theme.Colors.destructive : Theme.Colors.foreground)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isDestructive ? Theme.Colors.destructive : Theme.Colors.mutedForeground)
            }
            .padding(14)
        }
    }
}

// Simple flow layout for constraints
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

#Preview {
    ProfileView()
}
