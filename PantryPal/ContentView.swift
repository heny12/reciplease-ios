//
//  ContentView.swift
//  Reciplease
//
//  Created by Henry Chipman on 1/21/26.
//

import SwiftUI
import StoreKit
import UIKit

private struct PlanAddGroceryFromActionsPayload: Identifiable {
    let dayKeys: [String]
    var id: String { dayKeys.sorted().joined(separator: "|") }
}

struct ContentView: View {
    @StateObject private var viewModel = PantryViewModel()
    @StateObject private var reviewPromptService = ReviewPromptService.shared
    @StateObject private var quickActionService = QuickActionService.shared
    @ObservedObject private var generationCredits = GenerationCreditsManager.shared
    @State private var selectedTab = 0
    @State private var isAppLoading = true
    @State private var showPaywall = false
    /// Bump the storage key (v2 → v3, etc.) when onboarding content changes enough that everyone should see it again.
    @AppStorage("Reciplease.HasCompletedOnboarding.v2") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    @State private var showCustomerCenter = false
    @State private var showQuickActionMenu = false
    @State private var showMoreMenuSheet = false
    @State private var showHelpSheet = false
    @State private var showScanCapture = false
    @State private var showCookbookRecipeScan = false
    @State private var showScanWebRecipe = false
    @State private var showGlobalRecipePrompt = false
    @State private var showGlobalAddIngredient = false
    @State private var showGlobalCreateCookbook = false
    @State private var showGenerateMealPlanSheet = false
    @State private var planAddGroceryFromActionsPayload: PlanAddGroceryFromActionsPayload?
    @State private var planGroceryEmptyAlertMessage: String?
    @State private var showGlobalFeedbackForm = false
    @State private var showScanFirstDialog = false
    @State private var showClearPantryConfirmation = false
    @Environment(\.requestReview) private var requestReview
    
    private var paywallSheetShouldShow: Bool {
        (showPaywall || viewModel.usageTracker.shouldShowPaywall) && !viewModel.isShowingRecipeDetail
    }

    /// Paywall must attach to the topmost presenter: main chrome vs onboarding full-screen cover.
    private func paywallSheetBinding(presentedWithOnboarding: Bool) -> Binding<Bool> {
        Binding(
            get: { paywallSheetShouldShow && (showOnboarding == presentedWithOnboarding) },
            set: { newValue in
                showPaywall = newValue
                if !newValue {
                    viewModel.usageTracker.onPaywallDismissed()
                }
            }
        )
    }

    private var generationLimitSheetBinding: Binding<Bool> {
        Binding(
            get: { generationCredits.showGenerationLimitSheet },
            set: { newValue in
                if !newValue {
                    generationCredits.dismissGenerationLimitSheet()
                }
            }
        )
    }

    /// Trailing: help (?) + settings (…). Primary actions use the custom tab bar + button.
    @ToolbarContentBuilder
    private var mainTabToolbarItems: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarTrailing) {
                mainTabTrailingButtons
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                mainTabTrailingButtons
            }
        }
    }

    private var mainTabTrailingButtons: some View {
        HStack(spacing: 0) {
            mainTabHelpToolbarButton
            mainTabMoreToolbarButton
        }
    }

    private var mainTabHelpToolbarButton: some View {
        Button {
            HapticFeedback.medium()
            closeQuickActionMenu()
            closeMoreMenuSheet()
            showHelpSheet.toggle()
        } label: {
            ZStack {
                Color.clear
                Image(systemName: "questionmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.pantryPrimary, Color.pantrySecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Help")
    }

    private func presentMainTabQuickActions() {
        HapticFeedback.medium()
        closeMoreMenuSheet()
        let opening = !showQuickActionMenu
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            showQuickActionMenu.toggle()
        }
        if opening {
            AppAnalytics.logActionsSheetOpened(source: "tab_bar_plus")
        }
    }

    private func mainCustomTabItemTapped(_ index: Int) {
        HapticFeedback.light()
        closeQuickActionMenu()
        closeMoreMenuSheet()
        if selectedTab == index {
            if let tbc = TabBarReselectShim.shared.hostTabBarController,
               index >= 0,
               index < (tbc.viewControllers?.count ?? 0),
               let root = tbc.viewControllers?[index] {
                handleTabBarReselect(selectedTabRoot: root)
            } else {
                presentQuickActionMenuFromTabReselect()
            }
        } else {
            selectedTab = index
        }
    }

    private var mainTabMoreToolbarButton: some View {
        Button {
            HapticFeedback.medium()
            closeQuickActionMenu()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                showMoreMenuSheet.toggle()
            }
        } label: {
            ZStack {
                Color.clear
                Image(systemName: "ellipsis")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.pantryPrimary, Color.pantrySecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
    }

    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    tabReselectHook(
                        IngredientsView(viewModel: viewModel, onRequestClearIngredients: {
                            showClearPantryConfirmation = true
                        }) {
                            openScanCapture()
                        }
                        .toolbarRole(.browser)
                        .toolbar {
                            mainTabToolbarItems
                        }
                    )
                }
                .tabItem {
                    Label("Pantry", systemImage: "refrigerator.fill")
                }
                .tag(0)

                NavigationStack {
                    tabReselectHook(
                        CookbooksView(viewModel: viewModel)
                            .toolbarRole(.browser)
                            .toolbar {
                                mainTabToolbarItems
                            }
                    )
                }
                .tabItem {
                    Label("Cookbooks", systemImage: "books.vertical.fill")
                }
                .tag(1)

                NavigationStack {
                    tabReselectHook(
                        PlanView(viewModel: viewModel) {
                            openGenerateMealPlan()
                        }
                            .toolbarRole(.browser)
                            .toolbar {
                                mainTabToolbarItems
                            }
                    )
                }
                .tabItem {
                    Label("Plan", systemImage: "calendar")
                }
                .tag(2)

                NavigationStack {
                    tabReselectHook(
                        GroceryView(viewModel: viewModel)
                            .toolbarRole(.browser)
                            .toolbar {
                                mainTabToolbarItems
                            }
                    )
                }
                .tabItem {
                    Label("Grocery List", systemImage: "cart.fill")
                }
                .tag(3)
            }
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !viewModel.isShowingRecipeDetail {
                    MainCustomTabBar(
                        selectedTab: $selectedTab,
                        onTabTap: mainCustomTabItemTapped,
                        onPlusTap: presentMainTabQuickActions
                    )
                }
            }
            .onChange(of: viewModel.shouldNavigateToIngredients) { shouldNavigate in
                if shouldNavigate {
                    if showScanCapture {
                        showScanCapture = false
                    }
                    selectedTab = 0
                    viewModel.shouldNavigateToIngredients = false
                }
            }
            .onChange(of: viewModel.shouldNavigateToScan) { shouldNavigate in
                if shouldNavigate {
                    openScanCapture()
                    viewModel.shouldNavigateToScan = false
                }
            }
            .onChange(of: viewModel.shouldOpenCookbookRecipeScan) { open in
                if open {
                    openCookbookRecipeScan()
                    viewModel.shouldOpenCookbookRecipeScan = false
                }
            }
            .onChange(of: viewModel.shouldOpenWebRecipeScan) { open in
                if open {
                    openScanWebRecipe()
                    viewModel.shouldOpenWebRecipeScan = false
                }
            }
            .onChange(of: viewModel.shouldOpenRecipeGeneratePrompt) { open in
                if open {
                    openRecipePrompt()
                    viewModel.shouldOpenRecipeGeneratePrompt = false
                }
            }
            .onChange(of: viewModel.shouldNavigateToCookbooks) { _, cookbookId in
                guard let cookbookId else { return }
                if showCookbookRecipeScan {
                    showCookbookRecipeScan = false
                }
                if showScanWebRecipe {
                    showScanWebRecipe = false
                }
                selectedTab = 1
                if viewModel.deepLinkedRecipeIdToOpen == nil {
                    viewModel.openCookbookDetailId = cookbookId
                }
                viewModel.shouldNavigateToCookbooks = nil
            }
            .onChange(of: viewModel.shouldNavigateToPlan) { go in
                if go {
                    selectedTab = 2
                    viewModel.shouldNavigateToPlan = false
                }
            }
            .onChange(of: viewModel.shouldNavigateToGroceryList) { go in
                if go {
                    selectedTab = 3
                    viewModel.shouldNavigateToGroceryList = false
                }
            }
            .onChange(of: selectedTab) { _ in
                closeQuickActionMenu()
                closeMoreMenuSheet()
                showHelpSheet = false
            }
            .sheet(isPresented: $showQuickActionMenu) {
                QuickActionSheetMenu(
                    viewModel: viewModel,
                    onScanIngredients: { openScanCapture() },
                    onGenerateRecipe: { openRecipePrompt() },
                    onScanRecipe: { openCookbookRecipeScan() },
                    onImportRecipe: { openScanWebRecipe() },
                    onNewCookbook: { openCreateCookbook() },
                    onGenerateMealPlan: { openGenerateMealPlan() },
                    onAddPlanToGroceryList: { openAddPlanToGroceryListFromActions() }
                )
            }
            .sheet(isPresented: $showGenerateMealPlanSheet) {
                GenerateMealPlanPlaceholderSheet(viewModel: viewModel)
            }
            .sheet(item: $planAddGroceryFromActionsPayload, onDismiss: {
                planAddGroceryFromActionsPayload = nil
            }) { payload in
                PlanDayAddToGrocerySheet(dayKeys: payload.dayKeys, viewModel: viewModel)
            }
            .sheet(isPresented: $showMoreMenuSheet) {
                SettingsQuickActionSheet(
                    generationCredits: generationCredits,
                    onLimitsAndUpgrades: {
                        showMoreMenuSheet = false
                        generationCredits.presentGenerationLimitSheet()
                    }
                )
            }
            .sheet(isPresented: $showHelpSheet) {
                TabHelpSheet(tab: selectedTab)
            }
            .sheet(isPresented: paywallSheetBinding(presentedWithOnboarding: false)) {
                PaywallView(
                    scenario: .upgrade,
                    isPresented: paywallSheetBinding(presentedWithOnboarding: false)
                )
            }
            .sheet(isPresented: generationLimitSheetBinding) {
                GenerationLimitSheet {
                    showPaywall = true
                }
            }
            .sheet(isPresented: $showCustomerCenter) {
                CustomerCenterView()
            }
            .fullScreenCover(isPresented: $showScanCapture) {
                NavigationStack {
                    PhotoCaptureView(viewModel: viewModel)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .interactiveDismissDisabled(true)
            }
            .fullScreenCover(isPresented: $showCookbookRecipeScan) {
                NavigationStack {
                    CookbookRecipeScanView(viewModel: viewModel)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .interactiveDismissDisabled(true)
            }
            .sheet(isPresented: $showScanWebRecipe) {
                ScanWebRecipeView(viewModel: viewModel)
            }
            .sheet(isPresented: $showGlobalRecipePrompt) {
                RecipePromptBottomSheet(viewModel: viewModel, isPresented: $showGlobalRecipePrompt)
                    .onAppear {
                        viewModel.isShowingRecipePrompt = true
                    }
                    .onDisappear {
                        viewModel.isShowingRecipePrompt = false
                    }
            }
            .sheet(isPresented: $showGlobalAddIngredient) {
                NavigationStack {
                    AddIngredientView(viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showGlobalCreateCookbook) {
                CreateCookbookView(viewModel: viewModel)
            }
            .sheet(isPresented: $showGlobalFeedbackForm) {
                FeedbackFormView(feedbackType: .feedback)
            }
            .fullScreenCover(isPresented: Binding(
                get: { viewModel.isGeneratingRecipes },
                set: { _ in }
            )) {
                RecipeGenerationLoadingView()
                    .background(Color.pantryPrimary.ignoresSafeArea())
            }
            .alert("Scan ingredients first", isPresented: $showScanFirstDialog) {
                Button("Scan Ingredients") {
                    openScanCapture()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Add at least one ingredient before generating recipes.")
            }
            .alert("Grocery list", isPresented: Binding(
                get: { planGroceryEmptyAlertMessage != nil },
                set: { if !$0 { planGroceryEmptyAlertMessage = nil } }
            )) {
                Button("OK", role: .cancel) {
                    planGroceryEmptyAlertMessage = nil
                }
            } message: {
                Text(planGroceryEmptyAlertMessage ?? "")
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(
                    viewModel: viewModel,
                    isPresented: $showOnboarding,
                    onCompletedFromLaunchpad: {
                        hasCompletedOnboarding = true
                    },
                    onScanIngredients: {
                        openScanCapture()
                    },
                    onScanCookbook: {
                        openCookbookRecipeScan()
                    },
                    onImportWebRecipe: {
                        openScanWebRecipe()
                    },
                    onNewCookbook: {
                        openCreateCookbook()
                    },
                    onGenerateMealPlan: {
                        openGenerateMealPlan()
                    },
                    onAddPlanToGroceryList: {
                        openAddPlanToGroceryListFromActions()
                    },
                    onUpgradeToPro: {
                        showPaywall = true
                    }
                )
                .interactiveDismissDisabled(true)
                .sheet(isPresented: paywallSheetBinding(presentedWithOnboarding: true)) {
                    PaywallView(
                        scenario: .upgrade,
                        isPresented: paywallSheetBinding(presentedWithOnboarding: true)
                    )
                }
            }
            .opacity(isAppLoading ? 0 : 1)
        }
        
        // Loading screen overlay
        if isAppLoading {
            SplashScreenView()
                .transition(.opacity)
        }
        }
        .onAppear {
            // Perform initialization tasks
            Task {
                await initializeApp()
            }
        }
        .onChange(of: reviewPromptService.shouldRequestReview) { shouldRequestReview in
            guard shouldRequestReview else { return }
            requestReview()
            reviewPromptService.consumeReviewRequest()
        }
        .onChange(of: quickActionService.pendingAction) { action in
            guard let action else { return }
            handlePendingQuickActionIfNeeded()
        }
        .onChange(of: isAppLoading) { _ in
            handlePendingQuickActionIfNeeded()
        }
        .onChange(of: showOnboarding) { _ in
            handlePendingQuickActionIfNeeded()
        }
        .onChange(of: showPaywall) { _ in
            handlePendingQuickActionIfNeeded()
        }
        .onOpenURL { url in
            print("🔗 Received URL: \(url.absoluteString)")
            Task {
                await handleIncomingURL(url)
            }
        }
        .confirmationDialog("Clear all ingredients?", isPresented: $showClearPantryConfirmation, titleVisibility: .visible) {
            Button("Clear All", role: .destructive) {
                HapticFeedback.medium()
                withAnimation {
                    viewModel.clearAllIngredients()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all ingredients from your pantry.")
        }
    }

    private func openScanCapture() {
        closeQuickActionMenu()
        // Guard against stale navigation flags from prior scan sessions.
        viewModel.shouldNavigateToIngredients = false
        viewModel.shouldNavigateToScan = false
        showScanCapture = true
    }

    private func openRecipePrompt() {
        closeQuickActionMenu()
        guard ensureGenerationCreditOrShowSheet() else { return }
        showGlobalRecipePrompt = true
    }

    private func openCookbookRecipeScan() {
        closeQuickActionMenu()
        guard ensureGenerationCreditOrShowSheet() else { return }
        viewModel.shouldNavigateToCookbooks = nil
        showCookbookRecipeScan = true
    }

    private func openScanWebRecipe() {
        closeQuickActionMenu()
        guard ensureGenerationCreditOrShowSheet() else { return }
        viewModel.shouldNavigateToCookbooks = nil
        showScanWebRecipe = true
    }

    /// Preflight for pantry generate, cookbook scan, and web recipe scan (shared generation credits).
    private func ensureGenerationCreditOrShowSheet() -> Bool {
        generationCredits.refreshPeriodsAndUsage()
        if generationCredits.canConsumeGenerationCredit() {
            return true
        }
        generationCredits.presentGenerationLimitSheet()
        return false
    }

    private func openAddIngredient() {
        closeQuickActionMenu()
        showGlobalAddIngredient = true
    }

    private func openCreateCookbook() {
        closeQuickActionMenu()
        showGlobalCreateCookbook = true
    }

    private func openGenerateMealPlan() {
        closeQuickActionMenu()
        showGenerateMealPlanSheet = true
    }

    private func openAddPlanToGroceryListFromActions() {
        closeQuickActionMenu()
        let keys = PlanDayAddToGrocerySheet.upcomingDayKeysWithPlannedMeals(viewModel: viewModel)
        guard !keys.isEmpty else {
            planGroceryEmptyAlertMessage = "No planned meals from today onward. Add recipes on the Plan tab first."
            return
        }
        planAddGroceryFromActionsPayload = PlanAddGroceryFromActionsPayload(dayKeys: keys)
    }

    private func closeQuickActionMenu() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showQuickActionMenu = false
        }
    }

    private func closeMoreMenuSheet() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showMoreMenuSheet = false
        }
    }

    /// Re-tap on the selected tab: pop that tab’s navigation stack to root if possible; only at root do we open the Actions sheet.
    private func handleTabBarReselect(selectedTabRoot: UIViewController) {
        closeMoreMenuSheet()
        guard let nav = navigationControllerHostingTabRoot(selectedTabRoot) else {
            presentQuickActionMenuFromTabReselect()
            return
        }
        if nav.viewControllers.count > 1 {
            nav.popToRootViewController(animated: true)
        } else {
            presentQuickActionMenuFromTabReselect()
        }
    }

    private func presentQuickActionMenuFromTabReselect() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            showQuickActionMenu = true
        }
        AppAnalytics.logActionsSheetOpened(source: "tab_reselect")
    }

    /// Finds the `UINavigationController` that owns SwiftUI `NavigationStack` pushes for this tab.
    private func navigationControllerHostingTabRoot(_ root: UIViewController) -> UINavigationController? {
        if let nav = root as? UINavigationController {
            return nav
        }
        if let nav = root.navigationController {
            return nav
        }
        for child in root.children {
            if let nav = child as? UINavigationController {
                return nav
            }
            if let nav = navigationControllerHostingTabRoot(child) {
                return nav
            }
        }
        return nil
    }

    /// Re-tapping the already-selected tab bar item: pop to root when deep in a stack, else open quick actions (UIKit forwards the tap; SwiftUI’s selection binding does not fire).
    @ViewBuilder
    private func tabReselectHook<Content: View>(_ content: Content) -> some View {
        content
            .background {
                TabBarReselectHook { _, selectedTabRoot in
                    handleTabBarReselect(selectedTabRoot: selectedTabRoot)
                }
            }
    }

    private func handlePendingQuickActionIfNeeded() {
        guard canProcessQuickActions else { return }
        guard let action = quickActionService.pendingAction else { return }
        handleQuickAction(action)
        quickActionService.consumePendingAction()
    }

    private var canProcessQuickActions: Bool {
        !isAppLoading && !showOnboarding && !showPaywall
    }

    private func handleQuickAction(_ action: QuickActionService.Action) {
        switch action {
        case .scanIngredients:
            openScanCapture()
        case .generateMealPlan:
            openGenerateMealPlan()
        case .scanCookbookRecipe:
            openCookbookRecipeScan()
        case .leaveFeedback:
            closeQuickActionMenu()
            showGlobalFeedbackForm = true
        }
    }
    
    private func initializeApp() async {
        // Data is already loaded in ViewModel.init(), but we'll wait a moment
        // to ensure everything is ready and provide a smooth splash experience
        
        await MainActor.run {
            GenerationCreditsManager.shared.refreshPeriodsAndUsage()
        }
        
        // Fetch user data in parallel (non-blocking, optional)
        Task {
            await UserService.shared.fetchUserData()
        }
        
        // Minimum splash screen display time for better UX
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 1 second
        
        // Hide loading screen with animation
        withAnimation(.easeOut(duration: 0.3)) {
            isAppLoading = false
        }
        await MainActor.run {
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
        }
    }
    
    /// Handles deep links such as reciplease://recipe/{id}
    private func handleIncomingURL(_ url: URL) async {
        let scheme = url.scheme?.lowercased() ?? "nil"
        let host = url.host?.lowercased() ?? "nil"
        print("🔍 handleIncomingURL called")
        print("   scheme = \(scheme), host = \(host), path = \(url.path)")
        
        guard scheme == "reciplease" else {
            print("⚠️ Ignoring URL with unsupported scheme: \(scheme)")
            return
        }
        
        // For URLs like reciplease://recipe/{id}, host == "recipe" and the first
        // non-slash path component is the id string.
        if host == "recipe" {
            let components = url.pathComponents.filter { $0 != "/" }
            print("   pathComponents (filtered) = \(components)")
            guard let idString = components.first, !idString.isEmpty else {
                print("❌ No recipe id component found in URL path")
                return
            }
            
            print("✅ Parsed deep link recipe id string: \(idString)")
            
            await viewModel.handleRecipeDeepLink(idString: idString)
        } else {
            print("⚠️ Ignoring URL with unsupported host: \(host)")
        }
    }
}

// MARK: - Tab bar reselect → quick actions sheet

private final class TabBarReselectShim: NSObject, UITabBarControllerDelegate {
    static let shared = TabBarReselectShim()

    /// Tab bar plus the root view controller for the tab being (re-)selected (same instance when re-tapping the current tab).
    var onReselect: ((UITabBarController, UIViewController) -> Void)?
    weak var wrappedDelegate: UITabBarControllerDelegate?
    weak var hostTabBarController: UITabBarController?

    func installIfNeeded(from viewController: UIViewController) {
        guard let tabBarController = viewController.tabBarController else { return }
        hostTabBarController = tabBarController
        Self.hideSystemTabBarCompletely(tabBarController.tabBar)

        guard tabBarController.delegate !== self else { return }
        wrappedDelegate = tabBarController.delegate as? UITabBarControllerDelegate
        tabBarController.delegate = self
    }

    /// SwiftUI's `.toolbar(.hidden, for: .tabBar)` often leaves a translucent strip; collapse the real `UITabBar` so only the custom bar shows.
    private static func hideSystemTabBarCompletely(_ tabBar: UITabBar) {
        tabBar.isHidden = true
        tabBar.alpha = 0
        tabBar.isUserInteractionEnabled = false
        tabBar.isTranslucent = false
        tabBar.backgroundImage = UIImage()
        tabBar.shadowImage = UIImage()
        tabBar.barTintColor = .clear
        tabBar.backgroundColor = .clear

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }

    /// Never forward `shouldSelect` — SwiftUI’s internal delegate can return `false` for normal tab changes (e.g. Cookbooks), which would snap selection back. We only use this callback to detect re-taps on the already-selected tab.
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if let selected = tabBarController.selectedViewController,
           viewController === selected {
            DispatchQueue.main.async { [weak self] in
                self?.onReselect?(tabBarController, viewController)
            }
        }
        return true
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        wrappedDelegate?.tabBarController?(tabBarController, didSelect: viewController)
    }
}

private struct TabBarReselectHook: UIViewControllerRepresentable {
    var onReselectCurrentTab: (UITabBarController, UIViewController) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        TabBarReselectShim.shared.onReselect = onReselectCurrentTab
        DispatchQueue.main.async {
            TabBarReselectShim.shared.installIfNeeded(from: uiViewController)
        }
    }
}

// MARK: - Tab help sheet

private struct TabHelpSheet: View {
    let tab: Int

    private var imageName: String {
        switch tab {
        case 0: return "1"
        case 1: return "3"
        case 2: return "4"
        case 3: return "5"
        default: return "1"
        }
    }

    private var title: String {
        switch tab {
        case 0: return "Your Pantry"
        case 1: return "Your Cookbooks"
        case 2: return "Meal Plan"
        case 3: return "Grocery List"
        default: return "How it works"
        }
    }

    private var description: String {
        switch tab {
        case 0: return "Keep track of the ingredients in your fridge, freezer, and cupboards. Reciplease uses your pantry as a basis to create recipes and meal plans using what you already have, saving you money and reducing food waste."
        case 1: return "Organize your recipes into digital cookbooks. Storing recipes in cookbooks allows you to easily group family recipes, recipes you want to try, and more. By default all new recipes are stored in your 'Uncategorized' cookbook."
        case 2: return "Plan out your meals for the week ahead. Use the meal planner to generate full meal plans automatically, or manually assign recipes to specific days and times. Once you're happy with your meal plan, you can send everything you need straight to your grocery list."
        case 3: return "Your grocery list tracks the ingredients you need to cook recipes. Add items in batch from your meal plan, from individual recipes, or add them manually. As you shop, check items off your list to track what's left."
        default: return ""
        }
    }

    var body: some View {
        PantryQuickActionSheetShell(minDetentHeight: 400) {
            VStack(alignment: .leading, spacing: 0) {
                BundleImage(imageName, inDirectory: "Assets/onboarding")
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .padding(.bottom, DesignTokens.spacingMD)

                Text(title)
                    .font(.pantryLargeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, DesignTokens.spacingSM)

                Text(description)
                    .font(.pantryTitle2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, DesignTokens.spacingMD)

                Color.clear.frame(height: DesignTokens.spacingXS)
            }
        }
    }
}

// MARK: - Quick action sheet (+ menu) & matching more menu

private struct QuickActionSheetMenu: View {
    @ObservedObject var viewModel: PantryViewModel
    let onScanIngredients: () -> Void
    let onGenerateRecipe: () -> Void
    let onScanRecipe: () -> Void
    let onImportRecipe: () -> Void
    let onNewCookbook: () -> Void
    let onGenerateMealPlan: () -> Void
    let onAddPlanToGroceryList: () -> Void

    var body: some View {
        PantryQuickActionSheetShell(minDetentHeight: 300) {
            menuColumn
        }
    }

    private var menuColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            PantryQuickActionSheetChrome.sheetTitle("Actions")
            PantryQuickActionSheetChrome.sectionHeader("Pantry", isFirst: true)
            PantryQuickActionSheetChrome.actionRow(title: "Scan Ingredients", systemImage: "camera.viewfinder", action: onScanIngredients)

            PantryQuickActionSheetChrome.sectionDivider

            PantryQuickActionSheetChrome.sectionHeader("Recipes")
            PantryQuickActionSheetChrome.actionRow(title: "Generate Recipe", systemImage: "wand.and.stars", action: onGenerateRecipe)
            PantryQuickActionSheetChrome.actionRow(title: "Scan Cookbook", systemImage: "doc.viewfinder.fill", action: onScanRecipe)
            PantryQuickActionSheetChrome.actionRow(title: "Import from Web", systemImage: "square.and.arrow.down", action: onImportRecipe)

            PantryQuickActionSheetChrome.sectionDivider

            PantryQuickActionSheetChrome.sectionHeader("Cookbooks")
            PantryQuickActionSheetChrome.actionRow(title: "Create Cookbook", systemImage: "plus.circle.fill", action: onNewCookbook)

            PantryQuickActionSheetChrome.sectionDivider

            PantryQuickActionSheetChrome.sectionHeader("Plan")
            PantryQuickActionSheetChrome.actionRow(
                title: "Generate Meal Plan",
                systemImage: "calendar.badge.plus",
                action: onGenerateMealPlan
            )
            PantryQuickActionSheetChrome.actionRow(
                title: "Add to Grocery List",
                systemImage: "cart.badge.plus",
                action: onAddPlanToGroceryList
            )

            PantryQuickActionSheetChrome.sectionDivider

            PantryQuickActionSheetChrome.sectionHeader("Groceries")
            PantryQuickActionSheetChrome.groceryListShareRow(
                exportBody: PantryViewModel.formattedGroceryListExportString(from: viewModel.groceryItems),
                listIsEmpty: viewModel.groceryItems.isEmpty
            )
            Color.clear.frame(height: DesignTokens.spacingXS)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ContentView()
}
