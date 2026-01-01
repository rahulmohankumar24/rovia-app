import Foundation
import HealthKit
import Combine

@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    // Set to false to use real HealthKit (requires NSHealthShareUsageDescription in Info.plist)
    private let useMockData = true

    private let healthStore = HKHealthStore()

    // Published properties for UI binding
    @Published var isAuthorized = false
    @Published var todaySteps: Int = 0
    @Published var todayActiveCalories: Int = 0
    @Published var todayExerciseMinutes: Int = 0
    @Published var todayStandHours: Int = 0
    @Published var lastNightSleep: Double = 0
    @Published var sleepQuality: String = "unknown"
    @Published var restingHR: Int = 0
    @Published var avgHRV: Int = 0
    @Published var latestWeight: Double = 0
    @Published var todayWorkouts: [WorkoutInfo] = []
    @Published var recoveryScore: Int = 70
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?

    private var cancellables = Set<AnyCancellable>()

    // HealthKit types to read
    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        if let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount) { types.insert(stepCount) }
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(activeEnergy) }
        if let exerciseTime = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) { types.insert(exerciseTime) }
        if let standTime = HKQuantityType.quantityType(forIdentifier: .appleStandTime) { types.insert(standTime) }
        if let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass) { types.insert(bodyMass) }
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) { types.insert(heartRate) }
        if let restingHR = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) { types.insert(restingHR) }
        if let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(hrv) }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        types.insert(HKWorkoutType.workoutType())
        return types
    }()

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async throws -> Bool {
        if useMockData {
            try await Task.sleep(nanoseconds: 500_000_000)
            isAuthorized = true
            return true
        }

        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit not available on this device")
            return false
        }

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    Task { @MainActor in
                        self.isAuthorized = success
                    }
                    continuation.resume(returning: success)
                }
            }
        }
    }

    // MARK: - Fetch Today's Metrics

    func fetchTodayMetrics() async throws {
        if useMockData {
            try await fetchMockMetrics()
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        async let steps = fetchSteps(from: startOfDay, to: now)
        async let activeCalories = fetchActiveCalories(from: startOfDay, to: now)
        async let exerciseMinutes = fetchExerciseMinutes(from: startOfDay, to: now)
        async let standHours = fetchStandHours(from: startOfDay, to: now)
        async let sleepData = fetchLastNightSleep()
        async let heartData = fetchHeartMetrics()
        async let weight = fetchLatestWeight()
        async let workouts = fetchTodayWorkouts(from: startOfDay, to: now)

        let (s, ac, em, sh, sleep, heart, w, wo) = try await (
            steps, activeCalories, exerciseMinutes, standHours,
            sleepData, heartData, weight, workouts
        )

        todaySteps = s
        todayActiveCalories = ac
        todayExerciseMinutes = em
        todayStandHours = sh
        lastNightSleep = sleep.hours
        sleepQuality = sleep.quality
        restingHR = heart.restingHR
        avgHRV = heart.hrv
        latestWeight = w
        todayWorkouts = wo
        recoveryScore = calculateRecoveryScore()
    }

    // MARK: - Mock Data

    private func fetchMockMetrics() async throws {
        try await Task.sleep(nanoseconds: 300_000_000)

        todaySteps = Int.random(in: 4000...12000)
        todayActiveCalories = Int.random(in: 200...600)
        todayExerciseMinutes = Int.random(in: 15...90)
        todayStandHours = Int.random(in: 6...12)
        lastNightSleep = Double.random(in: 5.5...8.5)
        sleepQuality = lastNightSleep >= 7 ? "good" : (lastNightSleep >= 6 ? "fair" : "poor")
        restingHR = Int.random(in: 55...75)
        avgHRV = Int.random(in: 30...70)
        latestWeight = 175.0

        if Bool.random() {
            todayWorkouts = [
                WorkoutInfo(
                    type: ["Running", "Strength Training", "Cycling", "HIIT"].randomElement()!,
                    duration: Int.random(in: 30...60),
                    calories: Int.random(in: 200...500),
                    startTime: Date().addingTimeInterval(-3600 * Double.random(in: 2...8))
                )
            ]
        } else {
            todayWorkouts = []
        }

        recoveryScore = calculateRecoveryScore()
    }

    // MARK: - Individual Metric Fetches

    private func fetchSteps(from start: Date, to end: Date) async throws -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            healthStore.execute(query)
        }
    }

    private func fetchActiveCalories(from start: Date, to end: Date) async throws -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let calories = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: Int(calories))
            }
            healthStore.execute(query)
        }
    }

    private func fetchExerciseMinutes(from start: Date, to end: Date) async throws -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else { return 0 }

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let minutes = result?.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                continuation.resume(returning: Int(minutes))
            }
            healthStore.execute(query)
        }
    }

    private func fetchStandHours(from start: Date, to end: Date) async throws -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .appleStandTime) else { return 0 }

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                // Stand time is in minutes, convert to hours
                let minutes = result?.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                continuation.resume(returning: Int(minutes / 60))
            }
            healthStore.execute(query)
        }
    }

    private func fetchLastNightSleep() async throws -> (hours: Double, quality: String) {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return (0, "unknown")
        }

        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictEndDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let sleepSamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: (0, "unknown"))
                    return
                }

                // Calculate total sleep time (only count asleep states)
                var totalSleepSeconds: Double = 0
                for sample in sleepSamples {
                    // Only count actual sleep (not in bed but awake)
                    if sample.value != HKCategoryValueSleepAnalysis.awake.rawValue {
                        totalSleepSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                    }
                }

                let hours = totalSleepSeconds / 3600
                let quality: String
                if hours < 5 { quality = "poor" }
                else if hours < 6.5 { quality = "fair" }
                else if hours < 8 { quality = "good" }
                else { quality = "excellent" }

                continuation.resume(returning: (hours, quality))
            }
            healthStore.execute(query)
        }
    }

    private func fetchHeartMetrics() async throws -> (restingHR: Int, hrv: Int) {
        async let rhr = fetchRestingHeartRate()
        async let hrv = fetchAverageHRV()
        return try await (rhr, hrv)
    }

    private func fetchRestingHeartRate() async throws -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: 0)
                    return
                }
                let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                continuation.resume(returning: Int(bpm))
            }
            healthStore.execute(query)
        }
    }

    private func fetchAverageHRV() async throws -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return 0 }

        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: Date(), options: .strictEndDate)

            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let hrv = result?.averageQuantity()?.doubleValue(for: .secondUnit(with: .milli)) ?? 0
                continuation.resume(returning: Int(hrv))
            }
            healthStore.execute(query)
        }
    }

    private func fetchLatestWeight() async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return 0 }

        return try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: 0)
                    return
                }
                let weight = sample.quantity.doubleValue(for: .pound())
                continuation.resume(returning: weight)
            }
            healthStore.execute(query)
        }
    }

    private func fetchTodayWorkouts(from start: Date, to end: Date) async throws -> [WorkoutInfo] {
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }

                let workoutInfos = workouts.map { workout in
                    // Use statistics API for iOS 18+ or fallback to deprecated property
                    var caloriesBurned: Double = 0
                    if #available(iOS 18.0, *) {
                        if let stats = workout.statistics(for: HKQuantityType(.activeEnergyBurned)) {
                            caloriesBurned = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                        }
                    } else {
                        caloriesBurned = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
                    }
                    return WorkoutInfo(
                        type: workout.workoutActivityType.name,
                        duration: Int(workout.duration / 60),
                        calories: Int(caloriesBurned),
                        startTime: workout.startDate
                    )
                }
                continuation.resume(returning: workoutInfos)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Recovery Score

    private func calculateRecoveryScore() -> Int {
        var scores: [Int] = []

        // Sleep score
        if lastNightSleep > 0 {
            if lastNightSleep < 4 { scores.append(10) }
            else if lastNightSleep < 5 { scores.append(30) }
            else if lastNightSleep < 6 { scores.append(50) }
            else if lastNightSleep < 7 { scores.append(70) }
            else if lastNightSleep < 8 { scores.append(85) }
            else if lastNightSleep <= 9 { scores.append(100) }
            else { scores.append(80) }
        }

        // HRV score
        if avgHRV > 0 {
            if avgHRV < 20 { scores.append(20) }
            else if avgHRV < 30 { scores.append(40) }
            else if avgHRV < 50 { scores.append(60) }
            else if avgHRV < 70 { scores.append(80) }
            else { scores.append(100) }
        }

        // Resting HR score
        if restingHR > 0 {
            if restingHR < 50 { scores.append(100) }
            else if restingHR < 60 { scores.append(90) }
            else if restingHR < 70 { scores.append(75) }
            else if restingHR < 80 { scores.append(60) }
            else { scores.append(40) }
        }

        guard !scores.isEmpty else { return 70 }
        return scores.reduce(0, +) / scores.count
    }

    // MARK: - Sync to Backend

    func syncToBackend() async throws {
        isSyncing = true
        defer { isSyncing = false }

        // Fetch latest metrics
        try await fetchTodayMetrics()

        // In mock mode, just simulate sync
        if useMockData {
            try await Task.sleep(nanoseconds: 500_000_000)
            lastSyncTime = Date()
            return
        }

        // Build workout array for API
        let workoutsForAPI = todayWorkouts.map { workout in
            [
                "type": workout.type,
                "duration": workout.duration,
                "calories": workout.calories,
                "startTime": ISO8601DateFormatter().string(from: workout.startTime)
            ] as [String: Any]
        }

        // Prepare sync request
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())

        let metrics: [String: Any] = [
            "steps": todaySteps,
            "activeCalories": todayActiveCalories,
            "exerciseMinutes": todayExerciseMinutes,
            "standHours": todayStandHours,
            "workouts": workoutsForAPI,
            "sleep": [
                "totalHours": lastNightSleep,
                "quality": sleepQuality
            ],
            "restingHR": restingHR,
            "hrvSamples": avgHRV > 0 ? [avgHRV] : [],
            "weight": latestWeight > 0 ? latestWeight : NSNull()
        ]

        // Call API
        try await APIService.shared.syncHealthData(
            date: todayString,
            metrics: metrics
        )

        lastSyncTime = Date()
    }
}

// MARK: - Workout Type Extension

extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .functionalStrengthTraining: return "Strength Training"
        case .traditionalStrengthTraining: return "Weight Training"
        case .yoga: return "Yoga"
        case .highIntensityIntervalTraining: return "HIIT"
        case .coreTraining: return "Core Training"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stair Climbing"
        case .crossTraining: return "Cross Training"
        case .pilates: return "Pilates"
        case .kickboxing: return "Kickboxing"
        case .dance: return "Dance"
        case .hiking: return "Hiking"
        default: return "Workout"
        }
    }
}
