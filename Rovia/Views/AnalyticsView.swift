import SwiftUI
import Charts

struct AnalyticsView: View {
    @State private var stats: WeeklyStats?
    @State private var weeklySummary: WeeklySummaryResponse?
    @State private var patterns: [PatternInsight] = []
    @State private var strengths: [StrengthInsight] = []
    @State private var opportunities: [OpportunityInsight] = []
    @State private var isLoading = true
    @State private var weeklyData: [DailyCalorieData] = []
    @State private var selectedTab: AnalyticsTab = .overview
    @State private var showCoachChat = false
    @State private var isPro = true // TODO: Fetch from profile

    enum AnalyticsTab: String, CaseIterable {
        case overview = "Overview"
        case insights = "Insights"
        case coach = "Coach"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Tab Bar
                tabBar

                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .overview:
                            overviewContent
                        case .insights:
                            insightsContent
                        case .coach:
                            coachContent
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .background(Theme.Colors.background)
                .refreshable {
                    await loadData()
                }
            }
            .background(Theme.Colors.background)
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Tab Bar
    private var tabBar: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Path")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Theme.Colors.foreground)

                    Text("Your nutrition journey")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.mutedForeground)
                }

                Spacer()

                // Pro Badge
                if isPro {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10))
                        Text("PRO")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Tabs
            HStack(spacing: 0) {
                ForEach(AnalyticsTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: iconFor(tab))
                                    .font(.system(size: 14))
                                Text(tab.rawValue)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(selectedTab == tab ? Theme.Colors.primary : Theme.Colors.mutedForeground)

                            Rectangle()
                                .fill(selectedTab == tab ? Theme.Colors.primary : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)

            Divider()
                .background(Theme.Colors.border)
        }
        .background(Theme.Colors.background)
    }

    private func iconFor(_ tab: AnalyticsTab) -> String {
        switch tab {
        case .overview: return "chart.bar.fill"
        case .insights: return "lightbulb.fill"
        case .coach: return "bubble.left.and.bubble.right.fill"
        }
    }

    // MARK: - Overview Content
    private var overviewContent: some View {
        VStack(spacing: 20) {
            // Weekly Summary Hero
            if let insight = weeklySummary?.insight {
                WeeklyInsightCard(insight: insight, stats: stats)
            }

            // Stats Row
            statsRow

            // Weekly Chart
            weeklyChartCard

            // Quick Actions Grid
            quickActionsGrid
        }
        .padding(.top, 16)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            AnalyticsStatCard(
                icon: "flame.fill",
                iconColor: Color.orange,
                value: "\(stats?.currentStreak ?? 0)",
                label: "Day Streak"
            )

            AnalyticsStatCard(
                icon: "checkmark.circle.fill",
                iconColor: Color.green,
                value: "\(stats?.daysOnTrack ?? 0)/7",
                label: "On Track"
            )

            AnalyticsStatCard(
                icon: "chart.line.uptrend.xyaxis",
                iconColor: Theme.Colors.primary,
                value: "\(stats?.avgCalories ?? 0)",
                label: "Avg Cal"
            )

            AnalyticsStatCard(
                icon: "bolt.fill",
                iconColor: Theme.Colors.protein,
                value: "\(stats?.avgProtein ?? 0)g",
                label: "Avg Protein"
            )
        }
    }

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("This Week")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.Colors.foreground)

                Spacer()

                if let target = stats?.targetCalories {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Theme.Colors.primary.opacity(0.5))
                            .frame(width: 6, height: 6)
                        Text("Target: \(target)")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.mutedForeground)
                    }
                }
            }

            if #available(iOS 16.0, *) {
                Chart(weeklyData) { day in
                    BarMark(
                        x: .value("Day", day.day),
                        y: .value("Calories", day.calories)
                    )
                    .foregroundStyle(
                        day.isToday ? Theme.Colors.primary :
                            (day.isOnTarget ? Theme.Colors.primary.opacity(0.6) : Theme.Colors.muted)
                    )
                    .cornerRadius(6)

                    if let target = stats?.targetCalories {
                        RuleMark(y: .value("Target", target))
                            .foregroundStyle(Theme.Colors.primary.opacity(0.4))
                            .lineStyle(StrokeStyle(dash: [5, 5]))
                    }
                }
                .frame(height: 160)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .foregroundStyle(Theme.Colors.mutedForeground)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(Theme.Colors.mutedForeground)
                    }
                }
            } else {
                SimpleBarChart(data: weeklyData, target: stats?.targetCalories)
            }

            // Legend
            HStack(spacing: 16) {
                LegendItem(color: Theme.Colors.primary, label: "On Target")
                LegendItem(color: Theme.Colors.muted, label: "Off Target")
            }
        }
        .padding(16)
        .background(Theme.Colors.card)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private var quickActionsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            QuickActionCard(
                icon: "trophy.fill",
                iconColor: .green,
                title: "Strengths",
                subtitle: "\(strengths.count) identified",
                isPro: true,
                action: { selectedTab = .insights }
            )

            QuickActionCard(
                icon: "arrow.up.right",
                iconColor: .orange,
                title: "Opportunities",
                subtitle: "\(opportunities.count) suggestions",
                isPro: true,
                action: { selectedTab = .insights }
            )
        }
    }

    // MARK: - Insights Content
    private var insightsContent: some View {
        VStack(spacing: 20) {
            // Strengths Section
            if !strengths.isEmpty {
                InsightSection(
                    title: "Your Strengths",
                    icon: "trophy.fill",
                    iconColor: .green
                ) {
                    ForEach(strengths) { strength in
                        StrengthCard(strength: strength)
                    }
                }
            }

            // Opportunities Section
            if !opportunities.isEmpty {
                InsightSection(
                    title: "Areas to Explore",
                    icon: "arrow.up.right",
                    iconColor: .orange
                ) {
                    ForEach(opportunities) { opportunity in
                        OpportunityCard(opportunity: opportunity)
                    }
                }
            }

            // Patterns Section
            if !patterns.isEmpty {
                InsightSection(
                    title: "Your Patterns",
                    icon: "brain.head.profile",
                    iconColor: .purple
                ) {
                    ForEach(patterns) { pattern in
                        PatternCard(pattern: pattern)
                    }
                }
            }

            // Empty State
            if strengths.isEmpty && opportunities.isEmpty && patterns.isEmpty {
                EmptyInsightsView()
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Coach Content
    private var coachContent: some View {
        VStack(spacing: 20) {
            NutritionCoachView()
        }
        .padding(.top, 16)
    }

    // MARK: - Data Loading
    private func loadData() async {
        do {
            async let statsTask = APIService.shared.fetchWeeklyStats()
            async let patternsTask = APIService.shared.fetchPatterns()
            async let strengthsTask = APIService.shared.fetchStrengths()
            async let opportunitiesTask = APIService.shared.fetchOpportunities()

            stats = try await statsTask
            patterns = (try? await patternsTask) ?? []
            strengths = (try? await strengthsTask) ?? []
            opportunities = (try? await opportunitiesTask) ?? []

            generateWeeklyData()
            generateMockInsight()
        } catch {
            print("Failed to load analytics: \(error)")
        }
        isLoading = false
    }

    private func generateWeeklyData() {
        let target = stats?.targetCalories ?? 2000
        weeklyData = (0..<7).reversed().map { daysAgo in
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            let calories = Int.random(in: Int(Double(target) * 0.75)...Int(Double(target) * 1.15))
            let isOnTarget = abs(calories - target) < Int(Double(target) * 0.15)
            return DailyCalorieData(
                day: formatter.string(from: date),
                calories: calories,
                isToday: daysAgo == 0,
                isOnTarget: isOnTarget
            )
        }.reversed().map { $0 }
    }

    private func generateMockInsight() {
        if weeklySummary == nil {
            weeklySummary = WeeklySummaryResponse(
                days: [],
                insight: "Solid week overall - you stayed close to your targets most days. Your protein intake has been consistent, which is great for your recomp goal.",
                avgCalories: stats?.avgCalories ?? 0,
                avgProtein: stats?.avgProtein ?? 0,
                daysOnTrack: stats?.daysOnTrack ?? 0,
                totalDays: 7
            )
        }

        // Generate mock insights if empty
        if strengths.isEmpty {
            strengths = [
                StrengthInsight(id: "1", title: "Consistent Protein", description: "You hit your protein target 5 out of 7 days this week", evidence: "Averaging 92% of daily protein goal"),
                StrengthInsight(id: "2", title: "Regular Meal Timing", description: "Your meals are well-spaced throughout the day", evidence: "Eating within optimal windows")
            ]
        }

        if opportunities.isEmpty {
            opportunities = [
                OpportunityInsight(id: "1", title: "Weekend Consistency", description: "Calories tend to spike on weekends", suggestion: "Plan meals ahead for Saturday and Sunday"),
                OpportunityInsight(id: "2", title: "Fiber Intake", description: "Could benefit from more fiber-rich foods", suggestion: "Add vegetables or whole grains to lunch")
            ]
        }

        if patterns.isEmpty {
            patterns = [
                PatternInsight(id: "1", title: "Higher calories on rest days", description: "You tend to eat more when not working out", frequency: "Weekly", type: "behavior"),
                PatternInsight(id: "2", title: "Protein-heavy breakfasts", description: "Your morning meals are protein-forward", frequency: "Daily", type: "positive")
            ]
        }
    }
}

// MARK: - Data Models
struct DailyCalorieData: Identifiable {
    let id = UUID()
    let day: String
    let calories: Int
    let isToday: Bool
    let isOnTarget: Bool
}

// MARK: - Supporting Views
struct AnalyticsStatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.Colors.foreground)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.mutedForeground)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.Colors.card)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

struct WeeklyInsightCard: View {
    let insight: String
    let stats: WeeklyStats?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("This Week")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.Colors.foreground)
                    Text("\(stats?.totalDaysLogged ?? 0) days analyzed")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.mutedForeground)
                }

                Spacer()
            }

            Text(insight)
                .font(.system(size: 14))
                .foregroundColor(Theme.Colors.foreground)
                .lineSpacing(3)
        }
        .padding(16)
        .background(Theme.Colors.card)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

struct QuickActionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isPro: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundColor(iconColor)
                    }

                    Spacer()

                    if isPro {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Colors.foreground)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.mutedForeground)
                }
            }
            .padding(14)
            .background(Theme.Colors.card)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.mutedForeground)
        }
    }
}

struct InsightSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                }

                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.Colors.foreground)

                Spacer()
            }

            content
        }
    }
}

struct StrengthCard: View {
    let strength: StrengthInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(strength.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.foreground)

            Text(strength.description)
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.mutedForeground)
                .lineSpacing(2)

            if let evidence = strength.evidence {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                    Text(evidence)
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.card)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

struct OpportunityCard: View {
    let opportunity: OpportunityInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(opportunity.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.foreground)

            Text(opportunity.description)
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.mutedForeground)
                .lineSpacing(2)

            if let suggestion = opportunity.suggestion {
                HStack(spacing: 5) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text(suggestion)
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.card)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

struct PatternCard: View {
    let pattern: PatternInsight

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 14))
                    .foregroundColor(.purple)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(pattern.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Colors.foreground)

                Text(pattern.description)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.mutedForeground)
            }

            Spacer()

            Text(pattern.frequency)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.purple)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.12))
                .cornerRadius(10)
        }
        .padding(14)
        .background(Theme.Colors.card)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

struct EmptyInsightsView: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.muted)
                    .frame(width: 56, height: 56)
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 24))
                    .foregroundColor(Theme.Colors.mutedForeground)
            }

            VStack(spacing: 4) {
                Text("Not enough data yet")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.Colors.foreground)

                Text("Log meals for 3+ days to unlock personalized insights about your eating patterns.")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.mutedForeground)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.card)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Nutrition Coach View
struct NutritionCoachView: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var pendingMeal: ParsedMeal?
    @FocusState private var isInputFocused: Bool

    private let suggestedQuestions = [
        "How did I do this week?",
        "What should I eat for dinner?",
        "Am I hitting my protein goals?",
        "What are my eating patterns?"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Chat Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.primary.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.Colors.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Nutrition Coach")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.Colors.foreground)
                    Text("Ask questions or log meals")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.mutedForeground)
                }

                Spacer()
            }
            .padding(14)
            .background(Theme.Colors.card)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)

            // Suggested Questions (when no messages)
            if messages.isEmpty {
                VStack(spacing: 8) {
                    Text("Try asking:")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.mutedForeground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 14)

                    ForEach(suggestedQuestions, id: \.self) { question in
                        Button {
                            sendMessage(question)
                        } label: {
                            HStack {
                                Text(question)
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.Colors.foreground)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.Colors.mutedForeground)
                            }
                            .padding(12)
                            .background(Theme.Colors.card)
                            .cornerRadius(14)
                            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Messages
            if !messages.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }

                            if isLoading {
                                HStack {
                                    TypingIndicator()
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                            }

                            // Pending meal confirmation
                            if let meal = pendingMeal {
                                MealConfirmationCard(meal: meal) {
                                    Task { await confirmMeal(meal) }
                                } onCancel: {
                                    pendingMeal = nil
                                }
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            Spacer()

            // Input Bar
            HStack(spacing: 10) {
                TextField("Ask anything or log a meal...", text: $inputText)
                    .font(.system(size: 15))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.Colors.muted.opacity(0.3))
                    .cornerRadius(24)
                    .focused($isInputFocused)
                    .onSubmit {
                        sendMessage(inputText)
                    }

                Button {
                    sendMessage(inputText)
                } label: {
                    ZStack {
                        Circle()
                            .fill(inputText.isEmpty ? Theme.Colors.muted : Theme.Colors.primary)
                            .frame(width: 40, height: 40)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(inputText.isEmpty ? Theme.Colors.mutedForeground : .white)
                    }
                }
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding(.top, 12)
        }
    }

    private func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let userMessage = ChatMessage(content: text, isUser: true, timestamp: Date())
        messages.append(userMessage)
        inputText = ""
        isLoading = true

        Task {
            do {
                let (response, meal) = try await APIService.shared.sendNutritionChat(message: text)
                let aiMessage = ChatMessage(content: response, isUser: false, timestamp: Date())
                messages.append(aiMessage)

                if let meal = meal {
                    pendingMeal = meal
                }
            } catch {
                let errorMessage = ChatMessage(
                    content: "Sorry, I couldn't process that request. Please try again.",
                    isUser: false,
                    timestamp: Date()
                )
                messages.append(errorMessage)
            }
            isLoading = false
        }
    }

    private func confirmMeal(_ meal: ParsedMeal) async {
        do {
            try await APIService.shared.logMealDirect(
                name: meal.name,
                calories: meal.calories,
                protein: meal.protein,
                carbs: meal.carbs,
                fat: meal.fat
            )
            let confirmMessage = ChatMessage(
                content: "Logged: \(meal.name) - \(meal.calories) cal, \(meal.protein)g protein",
                isUser: false,
                timestamp: Date()
            )
            messages.append(confirmMessage)
            pendingMeal = nil
        } catch {
            let errorMessage = ChatMessage(
                content: "Failed to log meal. Please try again.",
                isUser: false,
                timestamp: Date()
            )
            messages.append(errorMessage)
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundColor(message.isUser ? .white : Theme.Colors.foreground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(message.isUser ? Theme.Colors.primary : Theme.Colors.card)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(message.isUser ? 0 : 0.03), radius: 4, x: 0, y: 1)
            }

            if !message.isUser { Spacer(minLength: 60) }
        }
    }
}

struct TypingIndicator: View {
    @State private var dotIndex = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Theme.Colors.mutedForeground)
                    .frame(width: 5, height: 5)
                    .opacity(dotIndex == index ? 1 : 0.4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.Colors.card)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                dotIndex = (dotIndex + 1) % 3
            }
        }
    }
}

struct MealConfirmationCard: View {
    let meal: ParsedMeal
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(meal.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.Colors.foreground)
                Spacer()
            }

            HStack(spacing: 12) {
                MacroPill(value: "\(meal.calories)", label: "cal", color: Theme.Colors.calories)
                MacroPill(value: "\(meal.protein)g", label: "protein", color: Theme.Colors.protein)
                MacroPill(value: "\(meal.carbs)g", label: "carbs", color: Theme.Colors.carbs)
                MacroPill(value: "\(meal.fat)g", label: "fat", color: Theme.Colors.fat)
            }

            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.Colors.mutedForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.Colors.muted.opacity(0.3))
                        .cornerRadius(12)
                }

                Button(action: onConfirm) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                        Text("Log Meal")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.Colors.primary)
                    .cornerRadius(12)
                }
            }
        }
        .padding(14)
        .background(Theme.Colors.card)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

struct MacroPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.mutedForeground)
        }
        .frame(maxWidth: .infinity)
    }
}

// Fallback chart for iOS 15
struct SimpleBarChart: View {
    let data: [DailyCalorieData]
    let target: Int?

    var body: some View {
        GeometryReader { geometry in
            let maxValue = max(data.map(\.calories).max() ?? 1, target ?? 1)
            let barWidth = (geometry.size.width - CGFloat(data.count - 1) * 4) / CGFloat(data.count)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(data) { day in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(day.isToday ? Theme.Colors.primary : (day.isOnTarget ? Theme.Colors.primary.opacity(0.6) : Theme.Colors.muted))
                            .frame(width: barWidth, height: CGFloat(day.calories) / CGFloat(maxValue) * geometry.size.height * 0.8)

                        Text(day.day)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.mutedForeground)
                    }
                }
            }
        }
        .frame(height: 180)
    }
}

#Preview {
    AnalyticsView()
}
