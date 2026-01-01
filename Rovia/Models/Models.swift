import Foundation

// MARK: - User & Profile
struct UserProfile: Codable {
    let name: String?
    let sex: String
    let age: Int
    let heightFt: Int
    let heightIn: Int
    let weightLb: Int
    let goal: String
    let liftingDays: Int
    let stepsLevel: String
    let constraints: [String]
}

// MARK: - Macros
struct MacroTargets: Codable {
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
}

struct MacroProgress: Codable {
    let targets: MacroTargets
    let current: MacroTargets
    let remaining: MacroTargets
}

// MARK: - Meal Logs
struct MealLogEntry: Codable, Identifiable {
    let id: String
    let datetime: String
    let servings: Double
    let mealType: String?
    let orderTemplate: OrderTemplate?
    let foodCatalogItem: FoodCatalogItem?

    var displayName: String {
        orderTemplate?.title ?? foodCatalogItem?.name ?? "Unknown Meal"
    }

    var macros: MacroTargets {
        if let template = orderTemplate {
            return MacroTargets(
                calories: Int(Double(template.calories) * servings),
                protein: Int(Double(template.protein) * servings),
                carbs: Int(Double(template.carbs) * servings),
                fat: Int(Double(template.fat) * servings)
            )
        } else if let item = foodCatalogItem {
            return MacroTargets(
                calories: Int(Double(item.calories) * servings),
                protein: Int(Double(item.protein) * servings),
                carbs: Int(Double(item.carbs) * servings),
                fat: Int(Double(item.fat) * servings)
            )
        }
        return MacroTargets(calories: 0, protein: 0, carbs: 0, fat: 0)
    }
}

struct OrderTemplate: Codable {
    let title: String
    let restaurantBrand: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
}

struct FoodCatalogItem: Codable {
    let name: String
    let source: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
}

struct DailyMealLogs: Codable {
    let mealLogs: [MealLogEntry]
    let totals: MacroTargets
    let count: Int
}

// MARK: - Meal Suggestions
struct MealSuggestion: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let restaurant: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let distance: Double?
    let estimatedPrice: Double?
    let aiReasoning: String?
    let calorieFit: Int?
    let proteinFit: Int?
}

struct MealSuggestionsResponse: Codable {
    let suggestions: [MealSuggestion]
    let remaining: MacroTargets?
    let targetForMeal: MacroTargets?
    let agentType: String?
}

// MARK: - Restaurant Ingredients
struct RestaurantIngredient: Codable, Identifiable {
    let id: String
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let category: String
}

// MARK: - Weekly Stats
struct WeeklyStats: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let daysOnTrack: Int
    let totalDaysLogged: Int
    let avgCalories: Int
    let avgProtein: Int
    let weeklyGoalHit: Int
    let targetCalories: Int
    let targetProtein: Int
}

// MARK: - Pantry
struct PantryItem: Codable, Identifiable {
    let id: String
    let name: String
    let quantity: String?
    let category: String?
}

// MARK: - Recipe
struct Recipe: Codable {
    let name: String
    let description: String
    let ingredients: [String]
    let instructions: [String]
    let macros: MacroTargets
}

// MARK: - Apple Health
struct WorkoutInfo: Codable, Identifiable {
    var id: String { "\(type)-\(startTime.timeIntervalSince1970)" }
    let type: String
    let duration: Int  // minutes
    let calories: Int
    let startTime: Date
}

struct HealthSummaryResponse: Codable {
    let enabled: Bool
    let lastSync: String?
    let today: TodayHealth?
    let activityLevel: String?
    let recoveryStatus: String?
    let message: String?
    let adjustments: TargetAdjustments?
    let adjustmentReason: String?
}

struct TargetAdjustments: Codable {
    let calorieChange: Int
    let proteinChange: Int
    let reason: String?
}

struct TodayHealth: Codable {
    let steps: Int
    let activeCalories: Int
    let exerciseMinutes: Int
    let standHours: Int
    let workouts: [WorkoutAPIInfo]
    let sleepHours: Double?
    let sleepQuality: String?
    let restingHR: Int?
    let hrv: Int?
    let weight: Double?
    let recoveryScore: Int
}

struct WorkoutAPIInfo: Codable {
    let type: String
    let duration: Int
    let calories: Int
}

struct HealthSyncResponse: Codable {
    let success: Bool
    let syncedAt: String?
    let dynamicTargets: DynamicTargets?
    let activityLevel: String?
    let recoveryStatus: String?
}

struct DynamicTargets: Codable {
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let adjustmentReason: String?
}

// MARK: - Health Insights (for Dashboard)
struct HealthInsights: Codable {
    let nutrientScore: Int?
    let dailySummary: String?
    let hasFruits: Bool?
    let hasVeggies: Bool?
    let hasFiber: Bool?
    let hasProbiotics: Bool?
    let hasVitaminC: Bool?
    let hasVitaminD: Bool?
    let hasVitaminA: Bool?
    let hasIron: Bool?
    let hasCalcium: Bool?
    let hasOmega3: Bool?
    let hasAntioxidants: Bool?
    let hasPotassium: Bool?
    let hasMagnesium: Bool?
    let hasZinc: Bool?
    let hasBVitamins: Bool?
}

// MARK: - Analytics & Insights
struct WeeklySummaryResponse: Codable {
    let days: [DayBreakdown]
    let insight: String?
    let avgCalories: Int
    let avgProtein: Int
    let daysOnTrack: Int
    let totalDays: Int
}

struct DayBreakdown: Codable, Identifiable {
    var id: String { date }
    let date: String
    let dayName: String
    let calories: Int
    let protein: Int
    let targetCalories: Int
    let targetProtein: Int
    let mealsLogged: Int
    let isOnTrack: Bool
}

struct PatternInsight: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let frequency: String
    let type: String
}

struct StrengthInsight: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let evidence: String?
}

struct OpportunityInsight: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let suggestion: String?
}

struct IngredientAnalysis: Codable {
    let overallScore: Int
    let grade: String
    let mealsAnalyzed: Int
    let restaurantsVisited: Int
    let concerns: [IngredientConcern]
    let topRestaurant: RestaurantGrade?
    let watchList: RestaurantGrade?
}

struct IngredientConcern: Codable, Identifiable {
    let id: String
    let category: String
    let severity: String
    let mealCount: Int
    let description: String
    let alternatives: String?
}

struct RestaurantGrade: Codable {
    let name: String
    let score: Int
    let grade: String
    let mealCount: Int
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
}

struct AnalyticsChatResponse: Codable {
    let response: String
}
