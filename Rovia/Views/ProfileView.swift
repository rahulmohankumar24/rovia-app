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
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Stats Grid
                    statsGrid

                    // Daily Targets
                    dailyTargetsCard

                    // Activity & Preferences
                    preferencesCard

                    // Integrations
                    integrationsCard

                    // Account
                    accountCard

                    // Version
                    Text("Rovia v1.0.0")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.mutedForeground)
                        .padding(.top, 8)
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

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.Colors.primary, Theme.Colors.primary.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: "person.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(goalLabel)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.Colors.foreground)

                Text("Goal")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.mutedForeground)
            }

            Spacer()

            // Edit Button
            Button {
                // TODO: Edit profile
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Colors.primary)
                    .frame(width: 36, height: 36)
                    .background(Theme.Colors.primary.opacity(0.1))
                    .cornerRadius(10)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Stats Grid
    private var statsGrid: some View {
        HStack(spacing: 12) {
            ProfileStatCard(value: "\(profile?.age ?? 27)", label: "Age", icon: "calendar")
            ProfileStatCard(value: "\(profile?.heightFt ?? 5)'\(profile?.heightIn ?? 10)\"", label: "Height", icon: "ruler")
            ProfileStatCard(value: "\(profile?.weightLb ?? 175)", label: "Weight", unit: "lbs", icon: "scalemass")
        }
    }

    // MARK: - Daily Targets Card
    private var dailyTargetsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Daily Targets")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.Colors.foreground)

                Spacer()

                Button {
                    // TODO: Edit targets
                } label: {
                    Text("Edit")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.Colors.primary)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                TargetCell(value: targets?.calories ?? 2000, label: "Calories", color: Theme.Colors.calories, icon: "flame.fill")
                TargetCell(value: targets?.protein ?? 150, label: "Protein", unit: "g", color: Theme.Colors.protein, icon: "bolt.fill")
                TargetCell(value: targets?.carbs ?? 250, label: "Carbs", unit: "g", color: Theme.Colors.carbs, icon: "leaf.fill")
                TargetCell(value: targets?.fat ?? 70, label: "Fat", unit: "g", color: Theme.Colors.fat, icon: "drop.fill")
            }
        }
        .padding(20)
        .background(Theme.Colors.card)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Preferences Card
    private var preferencesCard: some View {
        VStack(spacing: 0) {
            ProfileRowItem(
                icon: "dumbbell.fill",
                iconColor: .orange,
                title: "Lifting Days",
                value: "\(profile?.liftingDays ?? 4) days/week"
            )

            Divider().padding(.leading, 52)

            ProfileRowItem(
                icon: "figure.walk",
                iconColor: .blue,
                title: "Activity Level",
                value: activityLabel
            )

            if let constraints = profile?.constraints, !constraints.isEmpty {
                Divider().padding(.leading, 52)

                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "fork.knife")
                            .font(.system(size: 14))
                            .foregroundColor(.purple)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dietary")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.foreground)

                        FlowLayout(spacing: 6) {
                            ForEach(constraints, id: \.self) { constraint in
                                Text(constraint.capitalized)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Theme.Colors.foreground)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Theme.Colors.muted.opacity(0.5))
                                    .cornerRadius(8)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(16)
            }
        }
        .background(Theme.Colors.card)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Integrations Card
    private var integrationsCard: some View {
        VStack(spacing: 0) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Apple Health")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.Colors.foreground)

                        Text("PRO")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    }
                    Text("Sync activity & sleep data")
                        .font(.system(size: 12))
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
            .padding(16)

            if isAppleHealthEnabled {
                Divider().padding(.leading, 52)

                HStack {
                    Text("Last synced")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.mutedForeground)
                    Spacer()
                    if let lastSync = healthKit.lastSyncTime {
                        Text(lastSync, style: .relative)
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Colors.foreground)
                    } else {
                        Text("Never")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Colors.mutedForeground)
                    }

                    Button {
                        Task {
                            try? await healthKit.syncToBackend()
                        }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Colors.primary)
                    }
                    .padding(.leading, 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Theme.Colors.card)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Account Card
    private var accountCard: some View {
        VStack(spacing: 0) {
            AccountRowItem(icon: "envelope.fill", iconColor: .blue, title: "Contact Support") {
                contactSupport()
            }

            Divider().padding(.leading, 52)

            AccountRowItem(icon: "lock.shield.fill", iconColor: .gray, title: "Privacy Policy") {
                openPrivacy()
            }

            Divider().padding(.leading, 52)

            AccountRowItem(icon: "rectangle.portrait.and.arrow.right", iconColor: Theme.Colors.destructive, title: "Sign Out", isDestructive: true) {
                showLogoutConfirmation = true
            }
        }
        .background(Theme.Colors.card)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Computed Properties
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

    // MARK: - Functions
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
                    try await healthKit.fetchTodayMetrics()
                    try await healthKit.syncToBackend()
                } else {
                    isAppleHealthEnabled = false
                }
            } catch {
                print("Failed to enable Apple Health: \(error)")
                isAppleHealthEnabled = false
            }
            isRequestingHealthAccess = false
        }
    }
}

// MARK: - Supporting Views
struct ProfileStatCard: View {
    let value: String
    let label: String
    var unit: String = ""
    let icon: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Theme.Colors.primary)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.Colors.foreground)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.mutedForeground)
                }
            }

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.mutedForeground)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.Colors.card)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

struct TargetCell: View {
    let value: Int
    let label: String
    var unit: String = ""
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 1) {
                    Text("\(value)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.Colors.foreground)
                    Text(unit)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.mutedForeground)
                }
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.mutedForeground)
            }

            Spacer()
        }
        .padding(12)
        .background(Theme.Colors.muted.opacity(0.3))
        .cornerRadius(14)
    }
}

struct ProfileRowItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }

            Text(title)
                .font(.system(size: 14))
                .foregroundColor(Theme.Colors.foreground)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.Colors.mutedForeground)
        }
        .padding(16)
    }
}

struct AccountRowItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                }

                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(isDestructive ? Theme.Colors.destructive : Theme.Colors.foreground)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.mutedForeground)
            }
            .padding(16)
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
