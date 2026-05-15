//
//  OnboardingView.swift
//  PantryPal
//
//  First-run flow: non-dismissible, green shell; completion only from launchpad.
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: PantryViewModel
    @Binding var isPresented: Bool

    /// Persist `HasCompletedOnboarding` — call only when exiting from the launchpad.
    var onCompletedFromLaunchpad: () -> Void

    var onScanIngredients: () -> Void
    var onScanCookbook: () -> Void
    var onImportWebRecipe: () -> Void
    var onNewCookbook: () -> Void
    var onGenerateMealPlan: () -> Void
    var onAddPlanToGroceryList: () -> Void
    /// Opens the paywall (e.g. from the Free tier onboarding step).
    var onUpgradeToPro: () -> Void

    @State private var currentPage = 0
    @State private var loggedOnboardingPageViews: Set<Int> = []

    @State private var selectedPantrySuggestionIds: Set<String> = []
    /// Selection order is preserved for UserDefaults and generate-form chip ordering.
    @State private var selectedCuisinePreferenceOrder: [String] = []
    @State private var selectedDietaryPreferenceOrder: [String] = []
    /// Avoids re-adding pantry staples if the user goes back from step 3 and taps Continue again.
    @State private var didCommitPantryOnboardingSelections = false
    /// One-time default taps on the pantry step so selection affordance is obvious.
    @State private var didSeedDefaultPantryOnboardingSelections = false

    /// Accordion: which value-prop row is expanded on page index 1 (only one at a time). `nil` = all collapsed.
    @State private var expandedValuePropIndex: Int? = 0

    /// Coins revealed left-to-right on the “Cook for Free” page (page index 4).
    @State private var cookForFreeCoinRevealCount = 0

    private let totalPages = 6

    private static let valuePropositionLines: [(word: String, continuation: String, icon: String)] = [
        ("Track", "your ingredients with your digital pantry so that you can use what you have, reducing food waste and saving on grocery bills.", "cabinet.fill"),
        ("Create", "recipes by scanning your existing physical recipes, importing from the web, or generating with our powerful pantry AI.", "wand.and.stars"),
        ("Organize", "your recipes into digital cookbooks for easier access and shareability.", "books.vertical.fill"),
        ("Plan", "your meals for the week, either picking from your existing recipes or letting pantry AI come up with ones to fit your needs.", "calendar"),
        ("Shop", "all your ingredients you need for your weekly meal plan, minus what you already have, with smart grocery lists.", "cart.fill"),
    ]

    private var progress: CGFloat {
        CGFloat(currentPage + 1) / CGFloat(totalPages)
    }

    private var cuisinesForOnboarding: [OptionItem] {
        RecipeGenerationFormOptionData.cuisines.filter { $0.id != "Any" }
    }

    /// Omits items the app treats as pantry staples (same as recipe matching).
    private var pantryOnboardingSuggestionList: [OnboardingPantrySuggestion] {
        OnboardingPantrySuggestions.all.filter { !viewModel.recipeIngredientIsPantryStaple($0.generalName) }
    }

    var body: some View {
        ZStack {
            Color.pantryPrimary
                .ignoresSafeArea()

            Group {
                if currentPage == 0 {
                    welcomePage
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            bottomFooter
                        }
                        .transition(.opacity)
                } else {
                    VStack(spacing: 0) {
                        topChrome

                        Group {
                            switch currentPage {
                            case 1: valuePropositionPage
                            case 2: pantryOnboardingPage
                            case 3: cuisineDietPage
                            case 4: trialProPage
                            case 5: launchpadPage
                            default: valuePropositionPage
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)

                        bottomFooter
                    }
                }
            }
        }
        .onAppear {
            logOnboardingPageViewed(0)
        }
        .onChange(of: currentPage) { _, newPage in
            logOnboardingPageViewed(newPage)
            if newPage == 2, !didSeedDefaultPantryOnboardingSelections {
                didSeedDefaultPantryOnboardingSelections = true
                for suggestion in pantryOnboardingSuggestionList.prefix(3) {
                    selectedPantrySuggestionIds.insert(suggestion.id)
                }
            }
        }
    }

    // MARK: - Chrome

    private var topChrome: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            HStack(spacing: DesignTokens.spacingMD) {
                Button {
                    guard currentPage > 0 else { return }
                    HapticFeedback.light()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentPage -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.pantryHeadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.white.opacity(0.95))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.18)))
                }
                .buttonStyle(.plain)
                .disabled(currentPage <= 0)
                .opacity(currentPage <= 0 ? 0.35 : 1)
                .accessibilityLabel("Back")

                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.28))
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(8, w * progress))
                            .animation(.easeInOut(duration: 0.25), value: currentPage)
                    }
                }
                .frame(height: 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Onboarding progress")
                .accessibilityValue("\(currentPage + 1) of \(totalPages)")

                Color.clear
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.top, DesignTokens.spacingSM)
            .padding(.bottom, DesignTokens.spacingXS)
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            RecipleaseSplashHero()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var valuePropositionPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
                Text("What you can do with Reciplease")
                    .font(.pantryTitle2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white)

                VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                    ForEach(Array(Self.valuePropositionLines.enumerated()), id: \.offset) { index, line in
                        valuePropositionAccordionRow(
                            index: index,
                            line: line,
                            isExpanded: expandedValuePropIndex == index
                        )
                    }
                }
                .padding(.top, DesignTokens.spacingXS)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.top, DesignTokens.spacingMD)
            .padding(.bottom, DesignTokens.spacingLG)
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: expandedValuePropIndex)
        .onAppear {
            expandedValuePropIndex = 0
        }
    }

    private func valuePropositionAccordionRow(
        index: Int,
        line: (word: String, continuation: String, icon: String),
        isExpanded: Bool
    ) -> some View {
        let rowShape = RoundedRectangle(cornerRadius: DesignTokens.radiusMedium, style: .continuous)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                HapticFeedback.light()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    if expandedValuePropIndex == index {
                        expandedValuePropIndex = nil
                    } else {
                        expandedValuePropIndex = index
                    }
                }
            } label: {
                HStack(alignment: .center, spacing: DesignTokens.spacingMD) {
                    Image(systemName: line.icon)
                        .font(.pantryLargeTitle.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.98))
                        .frame(width: 56, height: 56, alignment: .center)
                        .accessibilityHidden(true)

                    Text(line.word)
                        .font(.pantryTitle2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)

                    Image(systemName: "chevron.down")
                        .font(.pantrySubheadline.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isExpanded)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, DesignTokens.spacingMD)
                .padding(.horizontal, DesignTokens.spacingMD)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(line.word)")
            .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand details")
            .accessibilityAddTraits(isExpanded ? [.isButton, .isSelected] : .isButton)

            if isExpanded {
                VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                    valuePropositionExpandedImage(forAccordionIndex: index)

                    (Text(line.word).fontWeight(.bold) + Text(" " + line.continuation))
                        .font(.pantryBody)
                        .foregroundStyle(Color.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.bottom, DesignTokens.spacingMD)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    )
                )
            }
        }
        .background(rowShape.fill(Color.white.opacity(0.14)))
        .overlay(rowShape.stroke(Color.white.opacity(0.22), lineWidth: 1))
        .clipShape(rowShape)
    }

    private var valuePropositionPlaceholderImage: some View {
        Image(systemName: "photo.on.rectangle.angled")
            .font(.system(size: 36, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.42))
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func valuePropositionExpandedImage(forAccordionIndex index: Int) -> some View {
        if (0..<Self.valuePropositionLines.count).contains(index) {
            BundleImage("\(index + 1)", inDirectory: "Assets/onboarding")
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .accessibilityHidden(true)
        } else {
            valuePropositionPlaceholderImage
        }
    }

    private var pantryOnboardingPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                Text("What's in Your Pantry?")
                    .font(.pantryTitle2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white)

                Text("Tap ingredients you already have in your kitchen.\n\nAdding ingredients to your pantry helps Reciplease better plan your meals and exclude ingredients you already have from your grocery list. Add some of the ingredients you have to get started.")
                    .font(.pantryBody)
                    .foregroundStyle(Color.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(pantryOnboardingSuggestionList) { suggestion in
                        pantryOnboardingIngredientRow(suggestion)
                    }
                }
                .padding(.top, DesignTokens.spacingSM)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.top, DesignTokens.spacingMD)
            .padding(.bottom, DesignTokens.spacingLG)
        }
    }

    /// Default quantity from onboarding suggestions when the user selects a row (no per-row quantity UI).
    private func defaultOnboardingPantryQuantity(for suggestion: OnboardingPantrySuggestion) -> String {
        suggestion.quantity.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let pantryOnboardingIconColumn: CGFloat = 48

    private func pantryOnboardingIngredientRow(_ suggestion: OnboardingPantrySuggestion) -> some View {
        let selected = selectedPantrySuggestionIds.contains(suggestion.id)

        return HStack(alignment: .center, spacing: DesignTokens.spacingMD) {
            IngredientPantryLeadingIcon(icon: getIngredientIcon(for: suggestion.generalName), tint: .white)
                .frame(
                    width: Self.pantryOnboardingIconColumn,
                    height: Self.pantryOnboardingIconColumn,
                    alignment: .center
                )

            Text(suggestion.generalName)
                .font(.pantryBody)
                .fontWeight(.bold)
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .minimumScaleFactor(0.88)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, PantryIngredientListMetrics.rowVPadding)
        .padding(.horizontal, DesignTokens.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white, lineWidth: 2.5)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            HapticFeedback.light()
            if selected {
                selectedPantrySuggestionIds.remove(suggestion.id)
            } else {
                selectedPantrySuggestionIds.insert(suggestion.id)
            }
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint("Double tap to \(selected ? "deselect" : "select") for your pantry")
    }

    private var cuisineDietPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
                Text("Tell us about your tastes and needs")
                    .font(.pantryTitle2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white)

                Text("Tell us what you like and we’ll use this to create recipes that match your tastes.")
                    .font(.pantrySubheadline)
                    .foregroundStyle(Color.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                Text("Cuisines")
                    .font(.pantryTitle3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white.opacity(0.98))

                FlowLayout(spacing: 10) {
                    ForEach(cuisinesForOnboarding) { item in
                        OptionChip(
                            option: item,
                            isSelected: selectedCuisinePreferenceOrder.contains(item.id),
                            style: .generateSheet,
                            size: .large
                        ) {
                            HapticFeedback.light()
                            toggleOnboardingCuisinePreference(item.id)
                        }
                    }
                }

                Text("Dietary")
                    .font(.pantryTitle3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white.opacity(0.98))
                    .padding(.top, DesignTokens.spacingSM)

                FlowLayout(spacing: 10) {
                    ForEach(RecipeGenerationFormOptionData.dietaryOptions) { item in
                        OptionChip(
                            option: item,
                            isSelected: selectedDietaryPreferenceOrder.contains(item.id),
                            style: .generateSheet,
                            size: .large
                        ) {
                            HapticFeedback.light()
                            toggleOnboardingDietaryPreference(item.id)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.top, DesignTokens.spacingMD)
            .padding(.bottom, DesignTokens.spacingLG)
        }
        .onAppear {
            selectedCuisinePreferenceOrder = RecipeGenerationFormOptionData.preferredCuisineIdsFromStorage()
            selectedDietaryPreferenceOrder = RecipeGenerationFormOptionData.preferredDietaryIdsFromStorage()
        }
    }

    private func toggleOnboardingCuisinePreference(_ id: String) {
        if let idx = selectedCuisinePreferenceOrder.firstIndex(of: id) {
            selectedCuisinePreferenceOrder.remove(at: idx)
        } else {
            selectedCuisinePreferenceOrder.append(id)
        }
        RecipeGenerationFormOptionData.persistPreferredCuisineIds(selectedCuisinePreferenceOrder)
    }

    private func toggleOnboardingDietaryPreference(_ id: String) {
        if let idx = selectedDietaryPreferenceOrder.firstIndex(of: id) {
            selectedDietaryPreferenceOrder.remove(at: idx)
        } else {
            selectedDietaryPreferenceOrder.append(id)
        }
        RecipeGenerationFormOptionData.persistPreferredDietaryIds(selectedDietaryPreferenceOrder)
    }

    private var cookForFreeCoinSlotCount: Int {
        min(AppConfig.trialMaxInteractions, 10)
    }

    private var cookForFreeCoinsRow: some View {
        let n = cookForFreeCoinSlotCount
        return HStack(spacing: DesignTokens.spacingSM) {
            ForEach(0..<n, id: \.self) { index in
                BundleImage("avi_coin")
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .opacity(cookForFreeCoinRevealCount > index ? 1 : 0)
                    .scaleEffect(cookForFreeCoinRevealCount > index ? 1 : 0.4)
                    .offset(y: cookForFreeCoinRevealCount > index ? 0 : 10)
            }
        }
        .padding(.top, DesignTokens.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(n) weekly recipe tokens")
    }

    private var trialProPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("You're on Reciplease Free")
                    .font(.pantryTitle2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white)

                cookForFreeCoinsRow

                Text(ProMarketingCopy.onboardingCookForFreeBody)
                    .font(.pantryBody)
                    .foregroundStyle(Color.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, DesignTokens.spacingMD)

                Text(ProMarketingCopy.onboardingUpgradeBridge)
                    .font(.pantryBody)
                    .foregroundStyle(Color.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, DesignTokens.spacingLG)

                Text(ProMarketingCopy.onboardingRecipleaseProSectionTitle)
                    .font(.pantryTitle2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, DesignTokens.spacingMD)
                    .padding(.bottom, 4)

                ProMarketingPaywallStyleBenefitsList()

                Text(ProMarketingCopy.monthlyResetFootnote)
                    .font(.pantryCaption)
                    .foregroundStyle(Color.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, DesignTokens.spacingSM)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.top, DesignTokens.spacingMD)
            .padding(.bottom, DesignTokens.spacingLG)
        }
        .onAppear {
            runCookForFreeCoinReveal()
        }
    }

    private func runCookForFreeCoinReveal() {
        let n = cookForFreeCoinSlotCount
        guard n > 0 else { return }
        cookForFreeCoinRevealCount = 0
        let stagger: TimeInterval = 0.12
        for i in 1...n {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i - 1) * stagger) {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.72)) {
                    cookForFreeCoinRevealCount = i
                }
            }
        }
    }

    private var launchpadPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                Text("You’re ready")
                    .font(.pantryTitle2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white)

                Text("Lets get started!")
                    .font(.pantrySubheadline)
                    .foregroundStyle(Color.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    launchpadButton(title: "Scan Ingredients", systemImage: "camera.viewfinder") {
                        completeFromLaunchpad { onScanIngredients() }
                    }
                    launchpadButton(title: "Generate Meal Plan", systemImage: "calendar.badge.plus") {
                        completeFromLaunchpad { onGenerateMealPlan() }
                    }
                    launchpadButton(title: "Scan Cookbook Recipe", systemImage: "doc.viewfinder.fill") {
                        completeFromLaunchpad { onScanCookbook() }
                    }
                    launchpadButton(title: "Import Recipe from Web", systemImage: "square.and.arrow.down") {
                        completeFromLaunchpad { onImportWebRecipe() }
                    }
                    launchpadButton(title: "Create Cookbook", systemImage: "plus.circle.fill") {
                        completeFromLaunchpad { onNewCookbook() }
                    }
                }
                .padding(.top, DesignTokens.spacingSM)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.top, DesignTokens.spacingMD)
            .padding(.bottom, DesignTokens.spacingLG)
        }
    }

    private func launchpadButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticFeedback.medium()
            action()
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .font(.pantryHeadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.pantryPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: systemImage)
                    .font(.pantryCustom(size: 20, weight: .semibold))
                    .foregroundStyle(Color.pantryPrimary)
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusLarge, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    // MARK: - Chips

    // MARK: - Footer

    private var bottomFooter: some View {
        VStack(spacing: 0) {
            if currentPage == 4 {
                Button {
                    HapticFeedback.light()
                    onUpgradeToPro()
                } label: {
                    Text("Upgrade to Pro")
                        .font(.pantryHeadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: DesignTokens.buttonHeightLarge)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.radiusLarge, style: .continuous)
                                .stroke(Color.white.opacity(0.92), lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DesignTokens.spacingLG)
                .padding(.top, DesignTokens.spacingMD)
                .accessibilityHint("Opens subscription options")
            }

            Button {
                HapticFeedback.medium()
                handlePrimaryFooterTap()
            } label: {
                Text(footerButtonTitle)
                    .font(.pantryHeadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.pantryPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: DesignTokens.buttonHeightLarge)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusLarge, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.top, currentPage == 4 ? DesignTokens.spacingSM : DesignTokens.spacingMD)
            .padding(.bottom, DesignTokens.spacingXL)
        }
        .background(Color.pantryPrimary)
    }

    private var footerButtonTitle: String {
        switch currentPage {
        case 0:
            return "Let's Get Cooking!"
        case totalPages - 1:
            return "Done"
        default:
            return "Continue"
        }
    }

    private func handlePrimaryFooterTap() {
        switch currentPage {
        case 0:
            withAnimation(.easeInOut(duration: 0.25)) { currentPage = 1 }
        case 1:
            withAnimation(.easeInOut(duration: 0.25)) { currentPage = 2 }
        case 2:
            if !didCommitPantryOnboardingSelections {
                commitPantrySelections()
                didCommitPantryOnboardingSelections = true
            }
            withAnimation(.easeInOut(duration: 0.25)) { currentPage = 3 }
        case 3:
            withAnimation(.easeInOut(duration: 0.25)) { currentPage = 4 }
        case 4:
            withAnimation(.easeInOut(duration: 0.25)) { currentPage = 5 }
        case 5:
            completeFromLaunchpad(nil)
        default:
            break
        }
    }

    private func commitPantrySelections() {
        let selected = pantryOnboardingSuggestionList.filter { selectedPantrySuggestionIds.contains($0.id) }
        let pairs = selected.map { item in
            (generalName: item.generalName, specificName: nil as String?, quantity: defaultOnboardingPantryQuantity(for: item))
        }
        viewModel.replacePantryIngredients(generalNameQuantityPairs: pairs)
    }

    private func completeFromLaunchpad(_ followUp: (() -> Void)?) {
        AppAnalytics.log(.onboardingCompleted, parameters: [
            "reason": followUp == nil ? "launchpad_primary" : "launchpad_action",
            "last_page_index": currentPage,
            "pages_total": totalPages
        ])
        onCompletedFromLaunchpad()
        isPresented = false
        if let followUp {
            DispatchQueue.main.async {
                followUp()
            }
        }
    }

    private func logOnboardingPageViewed(_ index: Int) {
        guard loggedOnboardingPageViews.insert(index).inserted else { return }
        AppAnalytics.log(.onboardingPageViewed, parameters: [
            "page_index": index,
            "pages_total": totalPages
        ])
    }
}

#Preview {
    OnboardingView(
        viewModel: PantryViewModel(),
        isPresented: .constant(true),
        onCompletedFromLaunchpad: {},
        onScanIngredients: {},
        onScanCookbook: {},
        onImportWebRecipe: {},
        onNewCookbook: {},
        onGenerateMealPlan: {},
        onAddPlanToGroceryList: {},
        onUpgradeToPro: {}
    )
}
