import Foundation
import Combine

// MARK: - API Service
class APIService: ObservableObject {
    static let shared = APIService()

    private let baseURL = "http://localhost:3000"  // Change to your production URL
    private let userId = "cmjmbwo9x000023euuuql3cme"  // Demo user ID

    private var timezone: String {
        TimeZone.current.identifier
    }

    // MARK: - Macro Progress
    func fetchMacroProgress() async throws -> MacroProgress {
        let url = URL(string: "\(baseURL)/api/macro-progress?userId=\(userId)&timezone=\(timezone)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(MacroProgress.self, from: data)
    }

    // MARK: - Meal Logs
    func fetchTodaysMealLogs() async throws -> DailyMealLogs {
        let url = URL(string: "\(baseURL)/api/log-meal?userId=\(userId)&timezone=\(timezone)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(DailyMealLogs.self, from: data)
    }

    func logMeal(orderTemplateId: String, servings: Double = 1) async throws {
        let url = URL(string: "\(baseURL)/api/log-meal")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "userId": userId,
            "orderTemplateId": orderTemplateId,
            "servings": servings
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.requestFailed
        }
    }

    func logMealDirect(name: String, calories: Int, protein: Int, carbs: Int, fat: Int) async throws {
        let url = URL(string: "\(baseURL)/api/log-meal-direct")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "userId": userId,
            "name": name,
            "calories": calories,
            "protein": protein,
            "carbs": carbs,
            "fat": fat
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.requestFailed
        }
    }

    func deleteMealLog(mealLogId: String) async throws {
        let url = URL(string: "\(baseURL)/api/log-meal?mealLogId=\(mealLogId)&userId=\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.requestFailed
        }
    }

    // MARK: - Meal Suggestions
    func fetchMealSuggestions(size: String = "regular") async throws -> MealSuggestionsResponse {
        let hour = Calendar.current.component(.hour, from: Date())
        let url = URL(string: "\(baseURL)/api/meal-suggestions?userId=\(userId)&size=\(size)&dining=takeout&travel=drive&timezone=\(timezone)&currentHour=\(hour)&limit=10")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(MealSuggestionsResponse.self, from: data)
    }

    // MARK: - Restaurant Ingredients
    func fetchRestaurantIngredients(brand: String) async throws -> [RestaurantIngredient] {
        let url = URL(string: "\(baseURL)/api/restaurant-ingredients?brand=\(brand)")!
        let (data, _) = try await URLSession.shared.data(from: url)

        struct Response: Codable {
            let ingredients: [RestaurantIngredient]
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.ingredients
    }

    // MARK: - Weekly Stats
    func fetchWeeklyStats() async throws -> WeeklyStats {
        let url = URL(string: "\(baseURL)/api/weekly-stats?userId=\(userId)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(WeeklyStats.self, from: data)
    }

    // MARK: - Profile
    func fetchProfile() async throws -> UserProfile {
        let url = URL(string: "\(baseURL)/api/profile?userId=\(userId)")!
        let (data, _) = try await URLSession.shared.data(from: url)

        struct Response: Codable {
            let profile: UserProfile
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.profile
    }

    func fetchDailyTargets() async throws -> MacroTargets {
        let url = URL(string: "\(baseURL)/api/daily-targets?userId=\(userId)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(MacroTargets.self, from: data)
    }

    // MARK: - Pantry
    func fetchPantryItems() async throws -> [PantryItem] {
        let url = URL(string: "\(baseURL)/api/pantry?userId=\(userId)")!
        let (data, _) = try await URLSession.shared.data(from: url)

        struct Response: Codable {
            let items: [PantryItem]
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.items
    }

    func addPantryItem(name: String, quantity: String?) async throws {
        let url = URL(string: "\(baseURL)/api/pantry")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["userId": userId, "name": name]
        if let quantity = quantity {
            body["quantity"] = quantity
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.requestFailed
        }
    }

    func deletePantryItem(itemId: String) async throws {
        let url = URL(string: "\(baseURL)/api/pantry?itemId=\(itemId)&userId=\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.requestFailed
        }
    }

    // MARK: - Health Analysis
    func fetchHealthInsights() async throws -> HealthInsights {
        let url = URL(string: "\(baseURL)/api/health-analysis?userId=\(userId)&today=true&timezone=\(timezone)")!
        let (data, response) = try await URLSession.shared.data(from: url)

        // Handle non-Pro users gracefully
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 403 {
            // Return empty insights for non-Pro users
            return HealthInsights(
                nutrientScore: nil,
                dailySummary: nil,
                hasFruits: nil,
                hasVeggies: nil,
                hasFiber: nil,
                hasProbiotics: nil,
                hasVitaminC: nil,
                hasVitaminD: nil,
                hasVitaminA: nil,
                hasIron: nil,
                hasCalcium: nil,
                hasOmega3: nil,
                hasAntioxidants: nil,
                hasPotassium: nil,
                hasMagnesium: nil,
                hasZinc: nil,
                hasBVitamins: nil
            )
        }

        return try JSONDecoder().decode(HealthInsights.self, from: data)
    }

    // MARK: - Apple Health Integration

    func syncHealthData(date: String, metrics: [String: Any]) async throws {
        let url = URL(string: "\(baseURL)/api/apple-health/sync")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "userId": userId,
            "date": date,
            "timezone": timezone,
            "metrics": metrics
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.requestFailed
        }

        // 403 means not Pro - handle gracefully
        if httpResponse.statusCode == 403 {
            return // Silently fail for non-Pro users
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
    }

    func fetchHealthSummary() async throws -> HealthSummaryResponse {
        let url = URL(string: "\(baseURL)/api/apple-health/summary?userId=\(userId)&timezone=\(timezone)")!
        let (data, response) = try await URLSession.shared.data(from: url)

        // Handle non-Pro users gracefully
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 403 {
            return HealthSummaryResponse(
                enabled: false,
                lastSync: nil,
                today: nil,
                activityLevel: nil,
                recoveryStatus: nil,
                message: "Pro subscription required",
                adjustments: nil,
                adjustmentReason: nil
            )
        }

        return try JSONDecoder().decode(HealthSummaryResponse.self, from: data)
    }

    // MARK: - Analytics & Insights

    func fetchWeeklySummary() async throws -> WeeklySummaryResponse {
        let url = URL(string: "\(baseURL)/api/weekly-summary?userId=\(userId)&timezone=\(timezone)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(WeeklySummaryResponse.self, from: data)
    }

    func fetchPatterns() async throws -> [PatternInsight] {
        let url = URL(string: "\(baseURL)/api/patterns/insights?userId=\(userId)")!
        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 403 {
            return []
        }

        struct Response: Codable {
            let patterns: [PatternInsight]
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.patterns
    }

    func fetchStrengths() async throws -> [StrengthInsight] {
        let url = URL(string: "\(baseURL)/api/insights/strengths?userId=\(userId)")!
        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 403 {
            return []
        }

        struct Response: Codable {
            let strengths: [StrengthInsight]
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.strengths
    }

    func fetchOpportunities() async throws -> [OpportunityInsight] {
        let url = URL(string: "\(baseURL)/api/insights/opportunities?userId=\(userId)")!
        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 403 {
            return []
        }

        struct Response: Codable {
            let opportunities: [OpportunityInsight]
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.opportunities
    }

    func fetchIngredientAnalysis() async throws -> IngredientAnalysis? {
        let url = URL(string: "\(baseURL)/api/health-analysis?userId=\(userId)")!
        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 403 {
            return nil
        }

        return try JSONDecoder().decode(IngredientAnalysis.self, from: data)
    }

    func sendAnalyticsChat(message: String) async throws -> String {
        let url = URL(string: "\(baseURL)/api/analytics-chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "userId": userId,
            "message": message,
            "timezone": timezone
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(AnalyticsChatResponse.self, from: data)
        return response.response
    }

    func sendNutritionChat(message: String) async throws -> (response: String, meal: ParsedMeal?) {
        let url = URL(string: "\(baseURL)/api/nutrition-chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "userId": userId,
            "message": message,
            "timezone": timezone
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        struct Response: Codable {
            let response: String
            let parsedMeal: ParsedMeal?
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return (decoded.response, decoded.parsedMeal)
    }
}

// MARK: - Parsed Meal from Chat
struct ParsedMeal: Codable {
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let servings: Double
}

// MARK: - API Errors
enum APIError: Error {
    case requestFailed
    case decodingFailed
    case invalidURL
}
