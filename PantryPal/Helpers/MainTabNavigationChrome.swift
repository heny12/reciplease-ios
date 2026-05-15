//
//  MainTabNavigationChrome.swift
//  PantryPal
//
//  Large titles on main tab roots (collapse to inline title when scrolling) + Avi logo leading.
//

import SwiftUI
import UIKit

enum MainTabNavigationCopy {
    static func pantryNavigationTitle(ingredientCount: Int) -> String {
        let n = ingredientCount
        if n == 0 { return "Pantry" }
        return n == 1 ? "Pantry · 1 item" : "Pantry · \(n) items"
    }

    static func cookbooksNavigationTitle(count: Int) -> String {
        switch count {
        case 0: return "Cookbooks"
        case 1: return "1 Cookbook"
        default: return "\(count) Cookbooks"
        }
    }

    static func planNavigationTitle(plannedMealSlotCount: Int) -> String {
        let n = plannedMealSlotCount
        if n == 0 { return "Plan" }
        return n == 1 ? "Plan · 1 Meal" : "Plan · \(n) Meals"
    }

    static func groceryNavigationTitle(itemCount: Int) -> String {
        let n = itemCount
        if n == 0 { return "Grocery List" }
        return n == 1 ? "Grocery List · 1 item" : "Grocery List · \(n) items"
    }
}

// MARK: - Avi mark (main tab bar)

private enum MainTabAviLogoMetrics {
    /// Slightly taller than wide (chef hat); sized for large-title nav without crowding the bar.
    static let height: CGFloat = 44
    static let maxWidth: CGFloat = 52
}

private struct MainTabAviLogoMark: View {
    var body: some View {
        BundleImage("avi_flat")
            .scaledToFit()
            .frame(height: MainTabAviLogoMetrics.height)
            .frame(maxWidth: MainTabAviLogoMetrics.maxWidth)
            .accessibilityHidden(true)
    }
}

/// Leading toolbar logo; tap presents a tip-of-the-day popover (same presentation style as pantry Insights pill).
private struct MainTabAviLogoToolbarItem: View {
    @ObservedObject private var tipService = TipOfDayService.shared
    @State private var tipPopoverPresented = false

    var body: some View {
        Button {
            HapticFeedback.light()
            tipPopoverPresented.toggle()
        } label: {
            MainTabAviLogoMark()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reciplease")
        .accessibilityHint("Shows today's cooking tip")
        .popover(isPresented: $tipPopoverPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            MainTabTipOfDayPopoverBody(tipService: tipService)
                .presentationCompactAdaptation(.popover)
        }
        .onChange(of: tipPopoverPresented) { _, isPresented in
            if isPresented {
                tipService.loadTipOfDay()
            }
        }
    }
}

private struct MainTabTipOfDayPopoverBody: View {
    @ObservedObject var tipService: TipOfDayService

    var body: some View {
        ScrollView {
            tipContent
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: min(300, UIScreen.main.bounds.width - 40), idealWidth: 340, maxHeight: 440)
        .padding(DesignTokens.spacingMD)
        .background(Color.pantrySurface)
    }

    @ViewBuilder
    private var tipContent: some View {
        if tipService.isLoading && tipService.tipOfDay == nil {
            HStack(spacing: DesignTokens.spacingSM) {
                ProgressView()
                    .controlSize(.regular)
                    .tint(.pantryTextSecondary)
                Text("Loading today's tip…")
                    .font(.pantryBody)
                    .foregroundColor(.pantryTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 2)
        } else if let tip = tipService.tipOfDay {
            VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                Text("Tip of the day")
                    .font(.pantrySubheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.pantryTextSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(tip.title)
                    .font(.pantryTitle3)
                    .fontWeight(.semibold)
                    .foregroundColor(.pantryTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(tip.content)
                    .font(.pantryBody)
                    .foregroundColor(.pantryTextPrimary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
        } else {
            Text("We couldn't load a tip right now. Tap the logo again in a moment to retry.")
                .font(.pantryBody)
                .foregroundColor(.pantryTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.horizontal, 2)
        }
    }
}

extension View {
    func mainTabRootNavigationChrome(title: String) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) {
                        MainTabAviLogoToolbarItem()
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) {
                        MainTabAviLogoToolbarItem()
                    }
                }
            }
            .contentMargins(.bottom, MainTabBarLayout.tabRootBottomScrollMargin, for: .scrollContent)
    }
}

// MARK: - Tab bar blur

/// Lighter than navigation chrome so scrolling content reads through more clearly (`systemUltraThinMaterial`).
private struct MainTabBarNavigationChromeBlur: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// MARK: - Custom main tab bar (system tab bar hidden; + is the center column)

/// Layout constants for the custom tab bar and tab-root scroll content.
enum MainTabBarLayout {
    /// Bottom margin for scrollable tab roots so the last content clears the custom bar + home indicator overlap.
    static let tabRootBottomScrollMargin: CGFloat = 76
}

struct MainCustomTabBar: View {
    @Binding var selectedTab: Int
    var onTabTap: (Int) -> Void
    var onPlusTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let plusColumnWidth: CGFloat = 62

    /// `safeAreaInset` already keeps this view above the home indicator; do not add window safe-area again
    /// (that doubled the gap under the icons).
    private var tabBarChromeBackground: some View {
        MainTabBarNavigationChromeBlur()
            .ignoresSafeArea(edges: .bottom)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            tabItem(index: 0, title: "Pantry", systemImage: "refrigerator.fill")
            tabItem(index: 1, title: "Cookbooks", systemImage: "books.vertical.fill")
            plusButton
                .frame(width: plusColumnWidth)
            tabItem(index: 2, title: "Plan", systemImage: "calendar")
            tabItem(index: 3, title: "Grocery", systemImage: "cart.fill")
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background { tabBarChromeBackground }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.06),
            radius: 4,
            y: -1
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(uiColor: UIColor.separator).opacity(colorScheme == .dark ? 0.35 : 0.28))
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tab bar")
    }

    @ViewBuilder
    private func tabItem(index: Int, title: String, systemImage: String) -> some View {
        let selected = selectedTab == index
        Button {
            onTabTap(index)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: .medium))
                Text(title)
                    .font(.pantryCaption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(selected ? Color.pantryPrimary : Color.pantryTextSecondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 1)
            .padding(.bottom, 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var plusButton: some View {
        Button {
            onPlusTap()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.pantryPrimary, Color.pantrySecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .shadow(color: Color.pantryPrimary.opacity(0.32), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Actions")
    }
}
