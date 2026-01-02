import SwiftUI

struct DashboardView: View {
    @State private var macros: MacroProgress?
    @State private var mealLogs: DailyMealLogs?
    @State private var healthInsights: HealthInsights?
    @State private var isLoading = true
    @State private var showQuickLog = false
    @State private var showFullLog = false
    @State private var selectedMealType: MealType = .breakfast
    @StateObject private var healthKit = HealthKitManager.shared
    @State private var healthSummary: HealthSummaryResponse?
    @State private var userName: String = "there"

    enum MealType: String, CaseIterable {
        case breakfast = "Breakfast"
        case lunch = "Lunch"
        case dinner = "Dinner"

        var icon: String {
            switch self {
            case .breakfast: return "sun.horizon.fill"
            case .lunch: return "sun.max.fill"
            case .dinner: return "moon.fill"
            }
        }

        var hourRange: ClosedRange<Int> {
            switch self {
            case .breakfast: return 0...10
            case .lunch: return 11...15
            case .dinner: return 16...23
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    private func mealsFor(_ type: MealType) -> [MealLogEntry] {
        guard let logs = mealLogs?.mealLogs else { return [] }
        return logs.filter { meal in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = formatter.date(from: meal.datetime) else { return false }
            let hour = Calendar.current.component(.hour, from: date)
            return type.hourRange.contains(hour)
        }
    }

    private func caloriesFor(_ type: MealType) -> Int {
        mealsFor(type).reduce(0) { $0 + $1.macros.calories }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with green accent
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(greeting), ")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Theme.Colors.foreground)
                            +
                            Text(userName)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Theme.Colors.primary)
                        }

                        Text(dateString)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.Colors.mutedForeground)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    // Health Insights (personalized message)
                    HealthInsightsCard(
                        sleepHours: healthSummary?.today?.sleepHours ?? 7.2,
                        steps: healthSummary?.today?.steps ?? 4500,
                        activeCalories: healthSummary?.today?.activeCalories ?? 280,
                        recoveryScore: healthSummary?.today?.recoveryScore ?? 72,
                        recoveryStatus: healthSummary?.recoveryStatus
                    )

                    // Progress Card - All Macros (Redesigned)
                    HStack(spacing: 8) {
                        // Calories Ring
                        VStack(spacing: 6) {
                            MacroRingView(
                                current: macros?.current.calories ?? 0,
                                target: macros?.targets.calories ?? 2000,
                                label: "cal",
                                color: Theme.Colors.calories,
                                size: 92,
                                lineWidth: 7
                            )
                            Text("\(macros?.remaining.calories ?? 0) left")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Theme.Colors.mutedForeground)
                        }
                        .frame(maxWidth: .infinity)

                        // Protein Ring
                        VStack(spacing: 6) {
                            MacroRingView(
                                current: macros?.current.protein ?? 0,
                                target: macros?.targets.protein ?? 150,
                                label: "protein",
                                color: Theme.Colors.protein,
                                size: 92,
                                lineWidth: 7
                            )
                            Text("\(macros?.remaining.protein ?? 0)g left")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Theme.Colors.mutedForeground)
                        }
                        .frame(maxWidth: .infinity)

                        // Carbs & Fat rings
                        VStack(spacing: 12) {
                            MacroRingView(
                                current: macros?.current.carbs ?? 0,
                                target: macros?.targets.carbs ?? 250,
                                label: "carbs",
                                color: Theme.Colors.carbs,
                                size: 60,
                                lineWidth: 5
                            )

                            MacroRingView(
                                current: macros?.current.fat ?? 0,
                                target: macros?.targets.fat ?? 70,
                                label: "fat",
                                color: Theme.Colors.fat,
                                size: 60,
                                lineWidth: 5
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(20)
                    .background(Theme.Colors.card)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)

                    // Today's Meals
                    TodaysMealsCard(
                        breakfastMeals: mealsFor(.breakfast),
                        lunchMeals: mealsFor(.lunch),
                        dinnerMeals: mealsFor(.dinner),
                        onAdd: { mealType in
                            selectedMealType = mealType
                            showQuickLog = true
                        },
                        onDelete: { id in
                            await deleteMeal(id)
                        },
                        onViewAll: {
                            showFullLog = true
                        }
                    )

                    // Today's Nutrients (Redesigned)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .center) {
                            Text("Nutrients")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Theme.Colors.foreground)

                            Spacer()

                            if let score = healthInsights?.nutrientScore {
                                HStack(spacing: 4) {
                                    Text("\(score)%")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(score >= 60 ? Theme.Colors.primary : (score >= 40 ? .orange : .red))
                                    Text("variety")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.Colors.mutedForeground)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background((score >= 60 ? Theme.Colors.primary : (score >= 40 ? Color.orange : Color.red)).opacity(0.1))
                                .cornerRadius(12)
                            }
                        }

                        // 2x3 grid of nutrient badges
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ], spacing: 8) {
                            NutrientChip(icon: "leaf.fill", label: "Veggies", isActive: healthInsights?.hasVeggies ?? false, activeColor: Theme.Colors.primary)
                            NutrientChip(icon: "drop.fill", label: "Iron", isActive: healthInsights?.hasIron ?? false, activeColor: .red)
                            NutrientChip(icon: "fish.fill", label: "Omega-3", isActive: healthInsights?.hasOmega3 ?? false, activeColor: .blue)
                            NutrientChip(icon: "circle.grid.3x3.fill", label: "Fiber", isActive: healthInsights?.hasFiber ?? false, activeColor: .orange)
                            NutrientChip(icon: "sun.max.fill", label: "Vitamin C", isActive: healthInsights?.hasVitaminC ?? false, activeColor: .yellow)
                            NutrientChip(icon: "figure.stand", label: "Calcium", isActive: healthInsights?.hasCalcium ?? false, activeColor: .cyan)
                        }
                    }
                    .padding(16)
                    .background(Theme.Colors.card)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)

                    // Activity Square (Apple Health)
                    ActivitySquare(
                        steps: healthSummary?.today?.steps ?? 4500,
                        activeCalories: healthSummary?.today?.activeCalories ?? 280,
                        sleepHours: healthSummary?.today?.sleepHours ?? 7.2,
                        recoveryScore: healthSummary?.today?.recoveryScore ?? 72,
                        recoveryStatus: healthSummary?.recoveryStatus ?? "good",
                        calorieAdjustment: healthSummary?.adjustments?.calorieChange,
                        proteinAdjustment: healthSummary?.adjustments?.proteinChange,
                        adjustmentReason: healthSummary?.adjustmentReason
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Theme.Colors.background)
            .refreshable {
                await loadData()
            }
        }
        .sheet(isPresented: $showQuickLog) {
            QuickLogSheet { message, image in
                await logMealWithAI(message: message, image: image)
            }
            .presentationDetents([.height(100)])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showFullLog) {
            FullMealLogSheet(
                mealLogs: mealLogs,
                macros: macros,
                onDelete: { id in
                    await deleteMeal(id)
                },
                onAddMeal: {
                    showFullLog = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showQuickLog = true
                    }
                }
            )
            .presentationDetents([.large])
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Data Loading
    private func loadData() async {
        do {
            async let macrosTask = APIService.shared.fetchMacroProgress()
            async let logsTask = APIService.shared.fetchTodaysMealLogs()
            async let healthTask = APIService.shared.fetchHealthInsights()
            async let healthSummaryTask = APIService.shared.fetchHealthSummary()
            async let profileTask = APIService.shared.fetchProfile()

            macros = try await macrosTask
            mealLogs = try await logsTask
            healthInsights = try? await healthTask
            healthSummary = try? await healthSummaryTask
            if let profile = try? await profileTask, let name = profile.name {
                userName = name.components(separatedBy: " ").first ?? name
            }
            isLoading = false
        } catch {
            print("Failed to load data: \(error)")
            isLoading = false
        }
    }

    private func logMealWithAI(message: String, image: UIImage?) async {
        // TODO: Send message and optional image to AI for analysis
        // The AI will parse the message (e.g., "chicken salad with avocado")
        // and/or analyze the photo to determine the meal and macros

        do {
            // Placeholder: In production, this would call an AI API
            // try await APIService.shared.logMealWithAI(message: message, image: image)

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            await loadData()
        } catch {
            print("Failed to log meal: \(error)")
        }
    }

    private func deleteMeal(_ id: String) async {
        do {
            try await APIService.shared.deleteMealLog(mealLogId: id)
            await loadData()
        } catch {
            print("Failed to delete meal: \(error)")
        }
    }
}

// MARK: - Health Insights Card
struct HealthInsightsCard: View {
    let sleepHours: Double?
    let steps: Int
    let activeCalories: Int
    let recoveryScore: Int
    let recoveryStatus: String?

    private var insight: (icon: String, title: String, message: String, color: Color) {
        if let sleep = sleepHours, sleep < 6 {
            return ("moon.zzz.fill", "Low Sleep Recovery", "You got \(String(format: "%.1f", sleep))hrs of sleep. Focus on protein-rich meals and stay hydrated to support recovery.", .purple)
        } else if recoveryScore < 50 {
            return ("heart.fill", "Recovery Day", "Your body needs rest. Consider lighter meals with anti-inflammatory foods like fish, leafy greens, and berries.", .orange)
        } else if steps > 10000 {
            return ("flame.fill", "High Activity", "Great movement today! You've burned \(activeCalories) active calories. Make sure to refuel with extra protein and carbs.", .green)
        } else if steps < 3000 {
            return ("figure.walk", "Get Moving", "Only \(steps) steps so far. A short walk after meals can help with digestion and energy levels.", .blue)
        } else if let sleep = sleepHours, sleep >= 7.5 {
            return ("sparkles", "Well Rested", "Great sleep last night! Your body is primed for muscle building. Hit your protein target today.", Theme.Colors.primary)
        } else {
            return ("leaf.fill", "Stay Balanced", "You're on track! Focus on nutrient-dense whole foods and staying hydrated throughout the day.", Theme.Colors.primary)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(insight.color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: insight.icon)
                    .font(.system(size: 20))
                    .foregroundColor(insight.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.foreground)

                Text(insight.message)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.mutedForeground)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.card)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Today's Meals Card (Redesigned)
struct TodaysMealsCard: View {
    let breakfastMeals: [MealLogEntry]
    let lunchMeals: [MealLogEntry]
    let dinnerMeals: [MealLogEntry]
    let onAdd: (DashboardView.MealType) -> Void
    let onDelete: (String) async -> Void
    let onViewAll: () -> Void

    private var totalCalories: Int {
        breakfastMeals.reduce(0) { $0 + $1.macros.calories } +
        lunchMeals.reduce(0) { $0 + $1.macros.calories } +
        dinnerMeals.reduce(0) { $0 + $1.macros.calories }
    }

    private var totalMeals: Int {
        breakfastMeals.count + lunchMeals.count + dinnerMeals.count
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Today's Meals")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.Colors.foreground)

                Spacer()

                if totalMeals > 0 {
                    Text("\(totalCalories) cal")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.Colors.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.primary.opacity(0.1))
                        .cornerRadius(12)
                }

                Button(action: onViewAll) {
                    HStack(spacing: 4) {
                        Text("View")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(Theme.Colors.mutedForeground)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Meal sections - no dividers, spaced vertically
            VStack(spacing: 14) {
                MealSection(
                    mealType: .breakfast,
                    meals: breakfastMeals,
                    onAdd: { onAdd(.breakfast) },
                    onDelete: onDelete
                )

                MealSection(
                    mealType: .lunch,
                    meals: lunchMeals,
                    onAdd: { onAdd(.lunch) },
                    onDelete: onDelete
                )

                MealSection(
                    mealType: .dinner,
                    meals: dinnerMeals,
                    onAdd: { onAdd(.dinner) },
                    onDelete: onDelete,
                    isLast: true
                )
            }
            .padding(.bottom, 16)
        }
        .background(Theme.Colors.card)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Meal Section (Redesigned - Horizontal Scroll)
struct MealSection: View {
    let mealType: DashboardView.MealType
    let meals: [MealLogEntry]
    let onAdd: () -> Void
    let onDelete: (String) async -> Void
    var isLast: Bool = false

    private var sectionCalories: Int {
        meals.reduce(0) { $0 + $1.macros.calories }
    }

    private var iconColor: Color {
        switch mealType {
        case .breakfast: return .orange
        case .lunch: return .yellow
        case .dinner: return .indigo
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Compact header row
            HStack(spacing: 8) {
                Image(systemName: mealType.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(iconColor)

                Text(mealType.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.foreground)

                if !meals.isEmpty {
                    Text("\(sectionCalories) cal")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(iconColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(iconColor.opacity(0.1))
                        .cornerRadius(10)
                }

                Spacer()
            }
            .padding(.horizontal, 16)

            // Horizontal scroll of meal cards (if meals exist)
            if !meals.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(meals) { meal in
                            MealItemCard(meal: meal) {
                                await onDelete(meal.id)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            // Full-width add button
            AddMealButton(onAdd: onAdd, hasMeals: !meals.isEmpty)
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - Meal Item Card (Compact)
struct MealItemCard: View {
    let meal: MealLogEntry
    let onDelete: () async -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(meal.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.Colors.foreground)
                .lineLimit(2)
                .frame(height: 32, alignment: .topLeading)

            Text("\(meal.macros.calories) cal")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.Colors.primary)

            HStack(spacing: 4) {
                Text("\(meal.macros.protein)g P")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.protein)
            }
        }
        .padding(12)
        .frame(width: 110, alignment: .leading)
        .background(Theme.Colors.muted.opacity(0.5))
        .cornerRadius(14)
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog("Delete this meal?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await onDelete() }
            }
        }
    }
}

// MARK: - Add Meal Button (Full Width)
struct AddMealButton: View {
    let onAdd: () -> Void
    var hasMeals: Bool = false

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text(hasMeals ? "Add more" : "Add meal")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(Theme.Colors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(Theme.Colors.primary.opacity(0.08))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.Colors.primary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Meal Row
struct MealRow: View {
    let meal: MealLogEntry
    let onDelete: () async -> Void

    @State private var showDeleteConfirmation = false

    private var timeString: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: meal.datetime) else { return "" }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "h:mm a"
        return displayFormatter.string(from: date)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.displayName)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.foreground)
                    .lineLimit(1)

                Text(timeString)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.mutedForeground)
            }

            Spacer()

            Text("\(meal.macros.calories) cal")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.Colors.mutedForeground)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Theme.Colors.muted.opacity(0.25))
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog("Delete this meal?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await onDelete() }
            }
        }
    }
}

// MARK: - Nutrient Chip (Redesigned)
struct NutrientChip: View {
    let icon: String
    let label: String
    let isActive: Bool
    let activeColor: Color

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isActive ? activeColor.opacity(0.15) : Theme.Colors.muted.opacity(0.5))
                    .frame(width: 28, height: 28)

                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(isActive ? activeColor : Theme.Colors.mutedForeground)
            }

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isActive ? Theme.Colors.foreground : Theme.Colors.mutedForeground)

            Spacer()

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(activeColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.Colors.muted.opacity(0.3))
        .cornerRadius(12)
    }
}

// MARK: - Activity Square (Redesigned - Horizontal Layout)
struct ActivitySquare: View {
    let steps: Int
    let activeCalories: Int
    let sleepHours: Double?
    let recoveryScore: Int
    let recoveryStatus: String?
    let calorieAdjustment: Int?
    let proteinAdjustment: Int?
    let adjustmentReason: String?

    private var recoveryColor: Color {
        switch recoveryStatus {
        case "excellent": return .green
        case "good": return Theme.Colors.primary
        case "fair": return .orange
        case "poor": return .red
        default: return Theme.Colors.primary
        }
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fk", Double(number) / 1000)
        }
        return "\(number)"
    }

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 13))
                    Text("Activity")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.Colors.foreground)
                }

                Spacer()

                if let cal = calorieAdjustment, cal != 0 {
                    HStack(spacing: 3) {
                        Image(systemName: cal > 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                        Text("\(abs(cal)) cal")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(cal > 0 ? .green : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((cal > 0 ? Color.green : Color.orange).opacity(0.12))
                    .cornerRadius(10)
                }
            }

            // Horizontal metrics row
            HStack(spacing: 0) {
                ActivityMetricTile(
                    icon: "figure.walk",
                    value: formatNumber(steps),
                    label: "Steps",
                    color: .green
                )

                ActivityMetricTile(
                    icon: "flame.fill",
                    value: "\(activeCalories)",
                    label: "Active",
                    color: .orange
                )

                ActivityMetricTile(
                    icon: "moon.fill",
                    value: sleepHours != nil ? String(format: "%.1f", sleepHours!) : "--",
                    label: "Sleep",
                    color: .purple
                )

                ActivityMetricTile(
                    icon: "heart.circle.fill",
                    value: "\(recoveryScore)",
                    label: "Recovery",
                    color: recoveryColor,
                    isLast: true
                )
            }
        }
        .padding(16)
        .background(Theme.Colors.card)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Activity Metric Tile (Flat, Horizontal)
struct ActivityMetricTile: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    var isLast: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            // Colored accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 24, height: 3)

            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.Colors.foreground)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.mutedForeground)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - Activity Card (Apple Health - Full)
struct ActivityCard: View {
    let steps: Int
    let activeCalories: Int
    let exerciseMinutes: Int
    let sleepHours: Double?
    let recoveryScore: Int
    let recoveryStatus: String?

    private var recoveryColor: Color {
        switch recoveryStatus {
        case "excellent": return .green
        case "good": return Theme.Colors.primary
        case "fair": return .orange
        case "poor": return .red
        default: return Theme.Colors.mutedForeground
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 16))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Activity")
                        .font(.system(size: Theme.Typography.lg, weight: .semibold))
                        .foregroundColor(Theme.Colors.foreground)
                    Text("From Apple Health")
                        .font(.system(size: Theme.Typography.xs))
                        .foregroundColor(Theme.Colors.mutedForeground)
                }

                Spacer()

                // Recovery Score
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(recoveryScore)")
                        .font(.system(size: Theme.Typography.xl, weight: .bold))
                        .foregroundColor(recoveryColor)
                    Text("recovery")
                        .font(.system(size: Theme.Typography.xs))
                        .foregroundColor(Theme.Colors.mutedForeground)
                }
            }

            // Activity Metrics Grid
            HStack(spacing: Theme.Spacing.md) {
                ActivityMetricPill(
                    icon: "figure.walk",
                    value: formatNumber(steps),
                    label: "steps",
                    color: .green
                )

                ActivityMetricPill(
                    icon: "flame.fill",
                    value: "\(activeCalories)",
                    label: "active cal",
                    color: .orange
                )

                ActivityMetricPill(
                    icon: "figure.run",
                    value: "\(exerciseMinutes)",
                    label: "min",
                    color: .blue
                )

                if let sleep = sleepHours {
                    ActivityMetricPill(
                        icon: "moon.fill",
                        value: String(format: "%.1f", sleep),
                        label: "hrs",
                        color: .purple
                    )
                }
            }

            // Recovery Bar
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text("Recovery")
                        .font(.system(size: Theme.Typography.xs))
                        .foregroundColor(Theme.Colors.mutedForeground)
                    Spacer()
                    Text(recoveryStatus?.capitalized ?? "")
                        .font(.system(size: Theme.Typography.xs, weight: .medium))
                        .foregroundColor(recoveryColor)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.Colors.muted)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(recoveryColor)
                            .frame(width: geometry.size.width * (Double(recoveryScore) / 100), height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(Theme.Spacing.xl)
        .background(Theme.Colors.card)
        .cornerRadius(Theme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fk", Double(number) / 1000)
        }
        return "\(number)"
    }
}

// MARK: - Activity Metric Pill
struct ActivityMetricPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: Theme.Typography.sm, weight: .bold))
                .foregroundColor(Theme.Colors.foreground)

            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Theme.Colors.mutedForeground)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(color.opacity(0.1))
        .cornerRadius(Theme.Radius.md)
    }
}

// MARK: - Full Meal Log Sheet
struct FullMealLogSheet: View {
    let mealLogs: DailyMealLogs?
    let macros: MacroProgress?
    let onDelete: (String) async -> Void
    let onAddMeal: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // Summary Card
                    VStack(spacing: Theme.Spacing.lg) {
                        Text("Today's Summary")
                            .font(.system(size: Theme.Typography.base, weight: .semibold))
                            .foregroundColor(Theme.Colors.foreground)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: Theme.Spacing.xl) {
                            SummaryStatItem(
                                value: "\(mealLogs?.totals.calories ?? 0)",
                                label: "Calories",
                                target: macros?.targets.calories ?? 2000,
                                current: mealLogs?.totals.calories ?? 0,
                                color: Theme.Colors.calories
                            )

                            SummaryStatItem(
                                value: "\(mealLogs?.totals.protein ?? 0)g",
                                label: "Protein",
                                target: macros?.targets.protein ?? 150,
                                current: mealLogs?.totals.protein ?? 0,
                                color: Theme.Colors.protein
                            )

                            SummaryStatItem(
                                value: "\(mealLogs?.totals.carbs ?? 0)g",
                                label: "Carbs",
                                target: macros?.targets.carbs ?? 250,
                                current: mealLogs?.totals.carbs ?? 0,
                                color: Theme.Colors.carbs
                            )

                            SummaryStatItem(
                                value: "\(mealLogs?.totals.fat ?? 0)g",
                                label: "Fat",
                                target: macros?.targets.fat ?? 70,
                                current: mealLogs?.totals.fat ?? 0,
                                color: Theme.Colors.fat
                            )
                        }
                    }
                    .padding(Theme.Spacing.xl)
                    .cardStyle()

                    // Meals List
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        HStack {
                            Text("Meals")
                                .font(.system(size: Theme.Typography.lg, weight: .semibold))
                                .foregroundColor(Theme.Colors.foreground)

                            Spacer()

                            Text("\(mealLogs?.count ?? 0) logged")
                                .font(.system(size: Theme.Typography.sm))
                                .foregroundColor(Theme.Colors.mutedForeground)
                        }

                        if let logs = mealLogs?.mealLogs, !logs.isEmpty {
                            ForEach(logs) { meal in
                                FullMealCard(meal: meal) {
                                    await onDelete(meal.id)
                                }
                            }
                        } else {
                            VStack(spacing: Theme.Spacing.md) {
                                Image(systemName: "fork.knife.circle")
                                    .font(.system(size: 48))
                                    .foregroundColor(Theme.Colors.muted)

                                Text("No meals logged yet")
                                    .font(.system(size: Theme.Typography.base))
                                    .foregroundColor(Theme.Colors.mutedForeground)

                                Text("Tap the button below to add your first meal")
                                    .font(.system(size: Theme.Typography.sm))
                                    .foregroundColor(Theme.Colors.mutedForeground)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.xxxl)
                        }
                    }

                    // Add Meal Button
                    Button(action: onAddMeal) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Meal")
                        }
                        .font(.system(size: Theme.Typography.base, weight: .semibold))
                        .foregroundColor(Theme.Colors.primaryForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.lg)
                        .background(Theme.Colors.primary)
                        .cornerRadius(Theme.Radius.md)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, 40)
            }
            .background(Theme.Colors.background)
            .navigationTitle(dateString)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.primary)
                }
            }
        }
    }
}

// MARK: - Summary Stat Item
struct SummaryStatItem: View {
    let value: String
    let label: String
    let target: Int
    let current: Int
    let color: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(value)
                .font(.system(size: Theme.Typography.lg, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: Theme.Typography.xs))
                .foregroundColor(Theme.Colors.mutedForeground)

            // Mini progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.Colors.muted)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Full Meal Card
struct FullMealCard: View {
    let meal: MealLogEntry
    let onDelete: () async -> Void

    @State private var showDeleteConfirmation = false

    private var timeString: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: meal.datetime) else { return "" }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "h:mm a"
        return displayFormatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(meal.displayName)
                        .font(.system(size: Theme.Typography.base, weight: .semibold))
                        .foregroundColor(Theme.Colors.foreground)

                    Text(timeString)
                        .font(.system(size: Theme.Typography.xs))
                        .foregroundColor(Theme.Colors.mutedForeground)
                }

                Spacer()

                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.destructive)
                        .padding(Theme.Spacing.sm)
                        .background(Theme.Colors.destructive.opacity(0.1))
                        .cornerRadius(Theme.Radius.sm)
                }
            }

            // Macro details
            HStack(spacing: Theme.Spacing.lg) {
                MacroDetail(value: "\(meal.macros.calories)", label: "cal", color: Theme.Colors.calories)
                MacroDetail(value: "\(meal.macros.protein)g", label: "protein", color: Theme.Colors.protein)
                MacroDetail(value: "\(meal.macros.carbs)g", label: "carbs", color: Theme.Colors.carbs)
                MacroDetail(value: "\(meal.macros.fat)g", label: "fat", color: Theme.Colors.fat)
            }
        }
        .padding(Theme.Spacing.lg)
        .cardStyle()
        .confirmationDialog("Delete this meal?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await onDelete() }
            }
        }
    }
}

// MARK: - Macro Detail
struct MacroDetail: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: Theme.Typography.sm, weight: .semibold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Theme.Colors.mutedForeground)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Compact Meal Card
struct CompactMealCard: View {
    let meal: MealLogEntry
    let onDelete: () async -> Void

    @State private var showDeleteConfirmation = false

    private var timeString: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: meal.datetime) else { return "" }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "h:mm a"
        return displayFormatter.string(from: date)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.displayName)
                    .font(.system(size: Theme.Typography.sm, weight: .medium))
                    .foregroundColor(Theme.Colors.foreground)
                    .lineLimit(1)

                Text(timeString)
                    .font(.system(size: Theme.Typography.xs))
                    .foregroundColor(Theme.Colors.mutedForeground)
            }

            Spacer()

            Text("\(meal.macros.calories) cal")
                .font(.system(size: Theme.Typography.sm, weight: .semibold))
                .foregroundColor(Theme.Colors.primary)
        }
        .padding(.vertical, Theme.Spacing.sm)
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog("Delete this meal?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await onDelete() }
            }
        }
    }
}

// MARK: - Supporting Views (keep existing ones)
struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(value)
                .font(.system(size: Theme.Typography.xl, weight: .bold))
                .foregroundColor(Theme.Colors.foreground)

            Text(label)
                .font(.system(size: Theme.Typography.xs))
                .foregroundColor(Theme.Colors.mutedForeground)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
        .cardStyle()
    }
}

struct MealLogCard: View {
    let meal: MealLogEntry
    let onDelete: () async -> Void

    @State private var showDeleteConfirmation = false

    private var timeString: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: meal.datetime) else { return "" }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "h:mm a"
        return displayFormatter.string(from: date)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(meal.displayName)
                    .font(.system(size: Theme.Typography.base, weight: .semibold))
                    .foregroundColor(Theme.Colors.foreground)
                    .lineLimit(1)

                Text(timeString)
                    .font(.system(size: Theme.Typography.xs))
                    .foregroundColor(Theme.Colors.mutedForeground)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(meal.macros.calories) cal")
                    .font(.system(size: Theme.Typography.base, weight: .semibold))
                    .foregroundColor(Theme.Colors.primary)

                Text("\(meal.macros.protein)g protein")
                    .font(.system(size: Theme.Typography.xs))
                    .foregroundColor(Theme.Colors.protein)
            }
        }
        .padding(Theme.Spacing.lg)
        .cardStyle()
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog("Delete this meal?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await onDelete() }
            }
        }
    }
}

struct EmptyMealsCard: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("No meals logged yet today")
                .font(.system(size: Theme.Typography.base))
                .foregroundColor(Theme.Colors.mutedForeground)

            Text("Tap \"Quick Log\" or visit AI Picks")
                .font(.system(size: Theme.Typography.sm))
                .foregroundColor(Theme.Colors.mutedForeground)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.xxl)
        .cardStyle()
    }
}

struct QuickLogSheet: View {
    let onSubmit: (String, UIImage?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""
    @State private var isLogging = false
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var selectedImage: UIImage?

    private var canSubmit: Bool {
        (!messageText.trimmingCharacters(in: .whitespaces).isEmpty || selectedImage != nil) && !isLogging
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)

            // Chat input area
            HStack(spacing: 8) {
                // Photo button or preview
                if let image = selectedImage {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipped()
                            .cornerRadius(8)

                        Button {
                            selectedImage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white, .black.opacity(0.6))
                        }
                        .offset(x: 4, y: -4)
                    }
                } else {
                    Menu {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
                        Button {
                            showImagePicker = true
                        } label: {
                            Label("Choose from Library", systemImage: "photo")
                        }
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.Colors.primary)
                            .frame(width: 36, height: 36)
                    }
                }

                // Text input bubble
                HStack(spacing: 8) {
                    TextField("What did you eat?", text: $messageText)
                        .font(.system(size: 16))

                    Button {
                        isLogging = true
                        Task {
                            await onSubmit(messageText, selectedImage)
                            isLogging = false
                            dismiss()
                        }
                    } label: {
                        Circle()
                            .fill(canSubmit ? Theme.Colors.primary : Color.gray.opacity(0.3))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Group {
                                    if isLogging {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "arrow.up")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(canSubmit ? .white : .gray)
                                    }
                                }
                            )
                    }
                    .disabled(!canSubmit)
                }
                .padding(.leading, 14)
                .padding(.trailing, 5)
                .padding(.vertical, 5)
                .background(Theme.Colors.input)
                .cornerRadius(22)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Theme.Colors.border, lineWidth: 1)
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Theme.Colors.background)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(image: $selectedImage, sourceType: .camera)
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Custom Styles
struct RoviaTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.input)
            .cornerRadius(Theme.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    DashboardView()
}
