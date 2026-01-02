import SwiftUI

struct AIPicksView: View {
    // Mode selection
    @State private var selectedMode: MealMode = .eatingOut

    enum MealMode: String, CaseIterable {
        case eatingOut = "Eating Out"
        case home = "Home Cooked"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Content
                if selectedMode == .eatingOut {
                    EatingOutView(selectedMode: $selectedMode)
                } else {
                    HomeView(selectedMode: $selectedMode)
                }
            }
            .background(Theme.Colors.background)
        }
    }
}

// MARK: - Eating Out View
struct EatingOutView: View {
    @Binding var selectedMode: AIPicksView.MealMode
    @State private var showRestaurantPicker = false
    @State private var suggestions: [MealSuggestion] = []
    @State private var targetForMeal: MacroTargets?
    @State private var remaining: MacroTargets?
    @State private var agentType: String = "lunch"
    @State private var isLoading = true
    @State private var selectedSize: MealSize = .regular
    @State private var loggedIds: Set<String> = []
    @State private var loggingId: String?

    // Restaurant state
    @State private var selectedBrand: String?
    @State private var ingredients: [RestaurantIngredient] = []
    @State private var selectedIngredients: Set<String> = []
    @State private var isLoadingIngredients = false
    @State private var searchQuery = ""

    private let supportedChains = [
        ("Chipotle", "chipotle"),
        ("Cava", "cava"),
        ("Sweetgreen", "sweetgreen"),
        ("Subway", "subway"),
        ("Panera", "panera"),
        ("Panda Express", "panda express")
    ]

    private var filteredChains: [(String, String)] {
        if searchQuery.isEmpty {
            return supportedChains
        }
        return supportedChains.filter { $0.0.localizedCaseInsensitiveContains(searchQuery) }
    }

    private var mealTotals: MacroTargets {
        let selected = ingredients.filter { selectedIngredients.contains($0.id) }
        return MacroTargets(
            calories: selected.reduce(0) { $0 + $1.calories },
            protein: selected.reduce(0) { $0 + $1.protein },
            carbs: selected.reduce(0) { $0 + $1.carbs },
            fat: selected.reduce(0) { $0 + $1.fat }
        )
    }

    private var ingredientsByCategory: [String: [RestaurantIngredient]] {
        Dictionary(grouping: ingredients, by: { $0.category })
    }

    enum MealSize: String, CaseIterable {
        case light, regular, hearty, feast
        var displayName: String { rawValue.capitalized }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Compact Header with Mode Toggle
                HStack(alignment: .center) {
                    Text("AI Picks")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.Colors.foreground)

                    Spacer()

                    // Compact Mode Toggle
                    HStack(spacing: 0) {
                        ForEach(AIPicksView.MealMode.allCases, id: \.self) { mode in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedMode = mode
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: mode == .eatingOut ? "fork.knife" : "house.fill")
                                        .font(.system(size: 11))
                                    Text(mode == .eatingOut ? "Restaurants" : "Home")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(selectedMode == mode ? Theme.Colors.primaryForeground : Theme.Colors.mutedForeground)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedMode == mode ? Theme.Colors.primary : Color.clear)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(3)
                    .background(Theme.Colors.muted)
                    .cornerRadius(10)
                }
                .padding(.top, 12)

                // Compact Search Button
                Button {
                    showRestaurantPicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Colors.mutedForeground)
                        Text("Search restaurants...")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.mutedForeground)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.Colors.card)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                }

                // Compact Size Selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MealSize.allCases, id: \.self) { size in
                            Button {
                                selectedSize = size
                                Task {
                                    isLoading = true
                                    await loadSuggestions()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if size == .feast {
                                        Image(systemName: "flame.fill")
                                            .font(.system(size: 10))
                                    }
                                    Text(size.displayName)
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(selectedSize == size ? Theme.Colors.primaryForeground : (size == .feast ? .orange : Theme.Colors.mutedForeground))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selectedSize == size ? (size == .feast ? Color.orange : Theme.Colors.primary) : Theme.Colors.card)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }

                // Target Card (compact)
                if let target = targetForMeal {
                    CompactTargetCard(target: target, remaining: remaining, agentType: agentType)
                }

                // Section Title
                HStack {
                    Text("Recommended")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Colors.mutedForeground)
                    Spacer()
                }

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primary))
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if suggestions.isEmpty {
                    EmptySuggestionsCard()
                } else {
                    ForEach(suggestions) { suggestion in
                        SuggestionCard(
                            suggestion: suggestion,
                            isLogged: loggedIds.contains(suggestion.id),
                            isLogging: loggingId == suggestion.id,
                            onLog: { await logMeal(suggestion) }
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .refreshable {
            await loadSuggestions()
        }
        .sheet(isPresented: $showRestaurantPicker) {
            RestaurantPickerSheet(
                selectedBrand: $selectedBrand,
                ingredients: $ingredients,
                selectedIngredients: $selectedIngredients,
                isLoadingIngredients: $isLoadingIngredients,
                searchQuery: $searchQuery,
                supportedChains: supportedChains,
                filteredChains: filteredChains,
                mealTotals: mealTotals,
                ingredientsByCategory: ingredientsByCategory,
                onSelectChain: selectChain,
                onToggleIngredient: toggleIngredient,
                onLogMeal: logCustomMeal
            )
        }
        .task {
            await loadSuggestions()
        }
    }

    private func loadSuggestions() async {
        do {
            let response = try await APIService.shared.fetchMealSuggestions(size: selectedSize.rawValue)
            suggestions = response.suggestions
            targetForMeal = response.targetForMeal
            remaining = response.remaining
            agentType = response.agentType ?? "lunch"
            isLoading = false
        } catch {
            print("Failed to load suggestions: \(error)")
            isLoading = false
        }
    }

    private func logMeal(_ suggestion: MealSuggestion) async {
        loggingId = suggestion.id
        do {
            try await APIService.shared.logMeal(orderTemplateId: suggestion.id)
            loggedIds.insert(suggestion.id)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            print("Failed to log meal: \(error)")
        }
        loggingId = nil
    }

    private func selectChain(_ brand: String) {
        selectedBrand = brand
        selectedIngredients = []
        isLoadingIngredients = true

        Task {
            do {
                ingredients = try await APIService.shared.fetchRestaurantIngredients(brand: brand)
            } catch {
                print("Failed to load ingredients: \(error)")
            }
            isLoadingIngredients = false
        }
    }

    private func toggleIngredient(_ id: String) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if selectedIngredients.contains(id) {
            selectedIngredients.remove(id)
        } else {
            selectedIngredients.insert(id)
        }
    }

    private func logCustomMeal() async {
        guard !selectedIngredients.isEmpty else { return }

        let mealName = "\(selectedBrand?.capitalized ?? "Custom") Bowl"

        do {
            try await APIService.shared.logMealDirect(
                name: mealName,
                calories: mealTotals.calories,
                protein: mealTotals.protein,
                carbs: mealTotals.carbs,
                fat: mealTotals.fat
            )

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            selectedIngredients = []
        } catch {
            print("Failed to log meal: \(error)")
        }
    }
}

// MARK: - Restaurant Picker Sheet
struct RestaurantPickerSheet: View {
    @Binding var selectedBrand: String?
    @Binding var ingredients: [RestaurantIngredient]
    @Binding var selectedIngredients: Set<String>
    @Binding var isLoadingIngredients: Bool
    @Binding var searchQuery: String

    let supportedChains: [(String, String)]
    let filteredChains: [(String, String)]
    let mealTotals: MacroTargets
    let ingredientsByCategory: [String: [RestaurantIngredient]]
    let onSelectChain: (String) -> Void
    let onToggleIngredient: (String) -> Void
    let onLogMeal: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isLogging = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if selectedBrand == nil {
                        // Search
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.Colors.mutedForeground)
                            TextField("Search restaurants...", text: $searchQuery)
                                .font(.system(size: 14))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Theme.Colors.card)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)

                        // Chain List
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Supported Chains")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.Colors.mutedForeground)

                            ForEach(filteredChains, id: \.1) { chain in
                                ChainCard(name: chain.0) {
                                    onSelectChain(chain.1)
                                }
                            }
                        }
                    } else {
                        // Meal Builder
                        VStack(spacing: 16) {
                            // Back button
                            Button {
                                withAnimation {
                                    selectedBrand = nil
                                    selectedIngredients = []
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 12))
                                    Text("Back")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(Theme.Colors.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // Running Totals
                            MealTotalsCard(
                                totals: mealTotals,
                                itemCount: selectedIngredients.count,
                                onLog: {
                                    isLogging = true
                                    await onLogMeal()
                                    isLogging = false
                                    dismiss()
                                }
                            )

                            if isLoadingIngredients {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primary))
                                    .frame(maxWidth: .infinity, minHeight: 150)
                            } else {
                                ForEach(ingredientsByCategory.keys.sorted(), id: \.self) { category in
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(category.capitalized)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(Theme.Colors.mutedForeground)

                                        ForEach(ingredientsByCategory[category] ?? []) { ingredient in
                                            IngredientCard(
                                                ingredient: ingredient,
                                                isSelected: selectedIngredients.contains(ingredient.id),
                                                onTap: { onToggleIngredient(ingredient.id) }
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Theme.Colors.background)
            .navigationTitle(selectedBrand?.capitalized ?? "Restaurants")
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

// MARK: - Home View (Pantry + Recipes)
struct HomeView: View {
    @Binding var selectedMode: AIPicksView.MealMode
    @State private var pantryItems: [PantryItem] = []
    @State private var isLoading = true
    @State private var showAddItem = false
    @State private var newItemName = ""
    @State private var newItemQuantity = ""
    @State private var recipeQuery = ""
    @State private var isLoadingRecipe = false
    @State private var generatedRecipe: Recipe?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Compact Header with Mode Toggle
                HStack(alignment: .center) {
                    Text("AI Picks")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.Colors.foreground)

                    Spacer()

                    // Compact Mode Toggle
                    HStack(spacing: 0) {
                        ForEach(AIPicksView.MealMode.allCases, id: \.self) { mode in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedMode = mode
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: mode == .eatingOut ? "fork.knife" : "house.fill")
                                        .font(.system(size: 11))
                                    Text(mode == .eatingOut ? "Restaurants" : "Home")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(selectedMode == mode ? Theme.Colors.primaryForeground : Theme.Colors.mutedForeground)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedMode == mode ? Theme.Colors.primary : Color.clear)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(3)
                    .background(Theme.Colors.muted)
                    .cornerRadius(10)
                }
                .padding(.top, 12)

                // Recipe Suggestion Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.primary)
                        Text("Get Recipe Ideas")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.Colors.foreground)
                    }

                    Text("Describe what you're craving")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.mutedForeground)

                    TextField("e.g., high protein dinner...", text: $recipeQuery, axis: .vertical)
                        .lineLimit(2...3)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(Theme.Colors.muted.opacity(0.5))
                        .cornerRadius(10)

                    Button {
                        // TODO: Implement recipe suggestion
                    } label: {
                        HStack(spacing: 6) {
                            if isLoadingRecipe {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primaryForeground))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 13))
                                Text("Get Recipe")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .foregroundColor(Theme.Colors.primaryForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.primary)
                        .cornerRadius(12)
                    }
                    .disabled(recipeQuery.isEmpty || isLoadingRecipe)
                    .opacity(recipeQuery.isEmpty ? 0.6 : 1)
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(16)
                .background(Theme.Colors.card)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)

                // My Pantry Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "refrigerator.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.Colors.primary)
                            Text("My Pantry")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Theme.Colors.foreground)
                        }

                        Spacer()

                        Button {
                            showAddItem = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11))
                                Text("Add")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(Theme.Colors.primary)
                        }
                    }

                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primary))
                            .frame(maxWidth: .infinity, minHeight: 80)
                    } else if pantryItems.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "basket")
                                .font(.system(size: 32))
                                .foregroundColor(Theme.Colors.muted)

                            Text("Your pantry is empty")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.Colors.mutedForeground)

                            Text("Add ingredients for personalized recipes")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.mutedForeground)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(Theme.Colors.card)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 90), spacing: 8)
                        ], spacing: 8) {
                            ForEach(pantryItems) { item in
                                PantryItemChip(item: item) {
                                    await deleteItem(item.id)
                                }
                            }
                        }
                    }
                }

                // Quick Add Suggestions
                if pantryItems.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Quick Add")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Colors.mutedForeground)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            QuickAddChip(name: "Chicken", onAdd: { await quickAdd("Chicken breast") })
                            QuickAddChip(name: "Eggs", onAdd: { await quickAdd("Eggs") })
                            QuickAddChip(name: "Rice", onAdd: { await quickAdd("Rice") })
                            QuickAddChip(name: "Spinach", onAdd: { await quickAdd("Spinach") })
                            QuickAddChip(name: "Salmon", onAdd: { await quickAdd("Salmon") })
                            QuickAddChip(name: "Avocado", onAdd: { await quickAdd("Avocado") })
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .refreshable {
            await loadPantryItems()
        }
        .sheet(isPresented: $showAddItem) {
            AddPantryItemSheet(
                name: $newItemName,
                quantity: $newItemQuantity,
                onAdd: addItem
            )
            .presentationDetents([.height(280)])
        }
        .task {
            await loadPantryItems()
        }
    }

    private func loadPantryItems() async {
        do {
            pantryItems = try await APIService.shared.fetchPantryItems()
        } catch {
            print("Failed to load pantry items: \(error)")
        }
        isLoading = false
    }

    private func addItem() async {
        guard !newItemName.isEmpty else { return }

        do {
            try await APIService.shared.addPantryItem(
                name: newItemName,
                quantity: newItemQuantity.isEmpty ? nil : newItemQuantity
            )
            newItemName = ""
            newItemQuantity = ""
            showAddItem = false
            await loadPantryItems()
        } catch {
            print("Failed to add item: \(error)")
        }
    }

    private func deleteItem(_ id: String) async {
        do {
            try await APIService.shared.deletePantryItem(itemId: id)
            await loadPantryItems()
        } catch {
            print("Failed to delete item: \(error)")
        }
    }

    private func quickAdd(_ name: String) async {
        do {
            try await APIService.shared.addPantryItem(name: name, quantity: nil)
            await loadPantryItems()
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } catch {
            print("Failed to quick add: \(error)")
        }
    }
}

// MARK: - Quick Add Chip
struct QuickAddChip: View {
    let name: String
    let onAdd: () async -> Void

    @State private var isAdding = false

    var body: some View {
        Button {
            isAdding = true
            Task {
                await onAdd()
                isAdding = false
            }
        } label: {
            HStack(spacing: 4) {
                if isAdding {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primary))
                        .scaleEffect(0.6)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 9))
                }
                Text(name)
                    .font(.system(size: 12))
            }
            .foregroundColor(Theme.Colors.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Theme.Colors.card)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
        .disabled(isAdding)
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Supporting Views
struct TargetCard: View {
    let target: MacroTargets
    let remaining: MacroTargets?
    let agentType: String

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HStack {
                Text("\(agentType.capitalized) Target")
                    .font(.system(size: Theme.Typography.base, weight: .semibold))
                    .foregroundColor(Theme.Colors.foreground)

                Spacer()

                Text(agentType)
                    .font(.system(size: Theme.Typography.xs, weight: .semibold))
                    .foregroundColor(Theme.Colors.primary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Theme.Colors.primary.opacity(0.15))
                    .cornerRadius(Theme.Radius.md)
            }

            HStack(spacing: Theme.Spacing.xxxl) {
                VStack {
                    Text("\(target.calories)")
                        .font(.system(size: Theme.Typography.display, weight: .bold))
                        .foregroundColor(Theme.Colors.primary)
                    Text("cal")
                        .font(.system(size: Theme.Typography.sm))
                        .foregroundColor(Theme.Colors.mutedForeground)
                }

                Rectangle()
                    .fill(Theme.Colors.border)
                    .frame(width: 1, height: 40)

                VStack {
                    Text("\(target.protein)g")
                        .font(.system(size: Theme.Typography.display, weight: .bold))
                        .foregroundColor(Theme.Colors.primary)
                    Text("protein")
                        .font(.system(size: Theme.Typography.sm))
                        .foregroundColor(Theme.Colors.mutedForeground)
                }
            }

            if let remaining = remaining {
                Text("\(remaining.calories) cal / \(remaining.protein)g protein remaining today")
                    .font(.system(size: Theme.Typography.sm))
                    .foregroundColor(Theme.Colors.mutedForeground)
            }
        }
        .padding(Theme.Spacing.xl)
        .cardStyle()
    }
}

// Compact version of TargetCard
struct CompactTargetCard: View {
    let target: MacroTargets
    let remaining: MacroTargets?
    let agentType: String

    var body: some View {
        HStack(spacing: 16) {
            // Target values
            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("\(target.calories)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.Colors.primary)
                    Text("cal")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.mutedForeground)
                }

                VStack(spacing: 2) {
                    Text("\(target.protein)g")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.Colors.protein)
                    Text("protein")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.mutedForeground)
                }
            }

            Spacer()

            // Remaining badge
            if let remaining = remaining {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(remaining.calories) cal left")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.Colors.mutedForeground)
                    Text("\(remaining.protein)g protein left")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.Colors.mutedForeground)
                }
            }

            // Meal type badge
            Text(agentType.capitalized)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.Colors.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.Colors.primary.opacity(0.12))
                .cornerRadius(8)
        }
        .padding(14)
        .background(Theme.Colors.card)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

struct SuggestionCard: View {
    let suggestion: MealSuggestion
    let isLogged: Bool
    let isLogging: Bool
    let onLog: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(suggestion.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.Colors.foreground)
                        .lineLimit(2)

                    Text(suggestion.restaurant)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.primary)
                }

                Spacer()

                if let distance = suggestion.distance {
                    Text(formatDistance(distance))
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.mutedForeground)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Theme.Colors.muted)
                        .cornerRadius(6)
                }
            }

            if let description = suggestion.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.mutedForeground)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                MacroChip(value: suggestion.calories, label: "cal", color: Theme.Colors.foreground)
                MacroChip(value: suggestion.protein, label: "protein", color: Theme.Colors.protein, unit: "g")
                MacroChip(value: suggestion.carbs, label: "carbs", color: Theme.Colors.foreground, unit: "g")
                MacroChip(value: suggestion.fat, label: "fat", color: Theme.Colors.foreground, unit: "g")
            }

            if suggestion.calorieFit != nil || suggestion.proteinFit != nil {
                HStack(spacing: 6) {
                    if let calFit = suggestion.calorieFit {
                        FitChip(label: "\(calFit)% cal fit", isGood: calFit >= 80)
                    }
                    if let proteinFit = suggestion.proteinFit {
                        FitChip(label: "\(proteinFit)% protein fit", isGood: proteinFit >= 80)
                    }
                }
            }

            if let reasoning = suggestion.aiReasoning, !reasoning.isEmpty {
                Text(reasoning)
                    .font(.system(size: 12))
                    .italic()
                    .foregroundColor(Theme.Colors.mutedForeground)
            }

            Button {
                Task { await onLog() }
            } label: {
                Text(isLogged ? "Logged" : isLogging ? "Logging..." : "Log Meal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isLogged ? Theme.Colors.primary : Theme.Colors.primaryForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isLogged ? Theme.Colors.muted.opacity(0.5) : Theme.Colors.primary)
                    .cornerRadius(12)
            }
            .disabled(isLogged || isLogging)
            .opacity(isLogging ? 0.6 : 1)
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .background(Theme.Colors.card)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func formatDistance(_ distance: Double) -> String {
        if distance < 1 {
            return "\(Int(distance * 1000))m"
        }
        return String(format: "%.1f mi", distance)
    }
}

struct FitChip: View {
    let label: String
    let isGood: Bool

    var body: some View {
        Text(label)
            .font(.system(size: Theme.Typography.xs))
            .foregroundColor(Theme.Colors.mutedForeground)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(isGood ? Theme.Colors.primary.opacity(0.15) : Theme.Colors.muted)
            .cornerRadius(Theme.Radius.sm)
    }
}

struct EmptySuggestionsCard: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("No suggestions available")
                .font(.system(size: Theme.Typography.base))
                .foregroundColor(Theme.Colors.mutedForeground)

            Text("Pull down to refresh")
                .font(.system(size: Theme.Typography.sm))
                .foregroundColor(Theme.Colors.mutedForeground)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .cardStyle()
    }
}

struct ChainCard: View {
    let name: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.Colors.foreground)

                Spacer()

                Text("Build")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.primary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.primary)
            }
            .padding(14)
            .background(Theme.Colors.card)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct MealTotalsCard: View {
    let totals: MacroTargets
    let itemCount: Int
    let onLog: () async -> Void

    @State private var isLogging = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Your Meal")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.foreground)

            HStack {
                TotalItem(value: "\(totals.calories)", label: "cal", color: Theme.Colors.primary)
                TotalItem(value: "\(totals.protein)g", label: "protein", color: Theme.Colors.protein)
                TotalItem(value: "\(totals.carbs)g", label: "carbs", color: Theme.Colors.foreground)
                TotalItem(value: "\(totals.fat)g", label: "fat", color: Theme.Colors.foreground)
            }

            if itemCount > 0 {
                Button {
                    isLogging = true
                    Task {
                        await onLog()
                        isLogging = false
                    }
                } label: {
                    Text(isLogging ? "Logging..." : "Log Meal (\(itemCount) items)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Colors.primaryForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.primary)
                        .cornerRadius(12)
                }
                .disabled(isLogging)
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(14)
        .background(Theme.Colors.card)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

struct TotalItem: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.mutedForeground)
        }
        .frame(maxWidth: .infinity)
    }
}

struct IngredientCard: View {
    let ingredient: RestaurantIngredient
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ingredient.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Colors.foreground)

                    Text("\(ingredient.calories) cal • \(ingredient.protein)g protein")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.mutedForeground)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.Colors.primary : Theme.Colors.border, lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(Theme.Colors.primary)
                            .frame(width: 22, height: 22)

                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.Colors.primaryForeground)
                    }
                }
            }
            .padding(12)
            .background(isSelected ? Theme.Colors.primary.opacity(0.05) : Theme.Colors.card)
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct PantryItemChip: View {
    let item: PantryItem
    let onDelete: () async -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 3) {
            Text(item.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.Colors.foreground)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if let quantity = item.quantity, !quantity.isEmpty {
                Text(quantity)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.mutedForeground)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(Theme.Colors.card)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog("Delete \(item.name)?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await onDelete() }
            }
        }
    }
}

struct AddPantryItemSheet: View {
    @Binding var name: String
    @Binding var quantity: String
    let onAdd: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Item name", text: $name)
                    .font(.system(size: 14))
                    .padding(12)
                    .background(Theme.Colors.muted.opacity(0.5))
                    .cornerRadius(12)

                TextField("Quantity (optional)", text: $quantity)
                    .font(.system(size: 14))
                    .padding(12)
                    .background(Theme.Colors.muted.opacity(0.5))
                    .cornerRadius(12)

                Button {
                    isAdding = true
                    Task {
                        await onAdd()
                        isAdding = false
                        dismiss()
                    }
                } label: {
                    Text(isAdding ? "Adding..." : "Add to Pantry")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Colors.primaryForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(name.isEmpty ? Theme.Colors.muted : Theme.Colors.primary)
                        .cornerRadius(12)
                }
                .disabled(name.isEmpty || isAdding)

                Spacer()
            }
            .padding(20)
            .background(Theme.Colors.background)
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 14))
                }
            }
        }
    }
}

#Preview {
    AIPicksView()
}
