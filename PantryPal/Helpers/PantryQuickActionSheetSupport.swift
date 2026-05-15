//
//  PantryQuickActionSheetSupport.swift
//  Shared chrome for orange quick-action style sheets (content-sized detent, page width on iOS 18+).
//

import SwiftUI
import UIKit

enum PantryQuickActionSheetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

enum PantryQuickActionSheetChrome {
    /// Shared top inset for scroll content in orange / green slide-up sheets.
    static let sheetScrollContentTopInset = DesignTokens.spacingLG
    /// Extra space above section headers: first block under the title (or after a form divider), vs. following a `sectionDivider`.
    private static let sectionHeaderTopInsetFirst = DesignTokens.spacingMD
    private static let sectionHeaderTopInsetFollowing = DesignTokens.spacingLG

    /// Large title at the top of a quick-action style sheet (Actions, Settings, Trial, …).
    static func sheetTitle(_ title: String) -> some View {
        Text(title)
            .font(.pantryTitle)
            .fontWeight(.bold)
            .foregroundStyle(Color.white)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, DesignTokens.spacingMD)
    }

    @ViewBuilder
    static func sectionHeader(_ name: String, isFirst: Bool = false) -> some View {
        Text(name.uppercased())
            .font(.pantrySubheadline)
            .fontWeight(.bold)
            .tracking(0.65)
            .foregroundStyle(Color.white.opacity(0.78))
            .padding(.top, isFirst ? sectionHeaderTopInsetFirst : sectionHeaderTopInsetFollowing)
            .padding(.bottom, DesignTokens.spacingSM)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    static var sectionDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.28))
            .frame(height: 1)
            .padding(.top, DesignTokens.spacingSM)
    }

    /// Horizontal rule with **equal** inset above and below for green generate / import / cookbook sheets.
    static var generateSheetSectionDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.28))
            .frame(height: 1)
            .padding(.top, DesignTokens.spacingMD)
            .padding(.bottom, DesignTokens.spacingMD)
    }

    /// Comfortable vertical rhythm and ~minimum touch height at default Dynamic Type.
    private static let rowVerticalPadding: CGFloat = 14

    static func actionRow(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticFeedback.medium()
            action()
        } label: {
            HStack(alignment: .center, spacing: DesignTokens.spacingSM) {
                Text(title)
                    .font(.pantryTitle3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Image(systemName: systemImage)
                    .font(.pantryTitle3.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.95))
            }
            .padding(.vertical, rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    /// Share formatted grocery text; dimmed and non-interactive when the list is empty.
    @ViewBuilder
    static func groceryListShareRow(exportBody: String, listIsEmpty: Bool) -> some View {
        GroceryListShareRow(exportBody: exportBody, listIsEmpty: listIsEmpty)
    }

    static func destructiveMenuRow(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticFeedback.medium()
            action()
        } label: {
            HStack(alignment: .center, spacing: DesignTokens.spacingSM) {
                Text(title)
                    .font(.pantryTitle3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(red: 1, green: 0.88, blue: 0.86))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Image(systemName: systemImage)
                    .font(.pantryTitle3.weight(.semibold))
                    .foregroundStyle(Color(red: 1, green: 0.88, blue: 0.86))
            }
            .padding(.vertical, rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct PantryQuickActionSheetShell<Inner: View>: View {
    var minDetentHeight: CGFloat = 220
    @ViewBuilder var inner: () -> Inner

    @State private var measuredContentHeight: CGFloat = 0

    private var maxSheetHeight: CGFloat {
        UIScreen.main.bounds.height * 0.92
    }

    private var detentHeight: CGFloat {
        let minH = minDetentHeight
        guard measuredContentHeight > 1 else { return minH }
        return min(max(measuredContentHeight, minH), maxSheetHeight)
    }

    var body: some View {
        ScrollView {
            inner()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, LayoutHelpers.quickActionSheetHorizontalPadding)
                .padding(.top, PantryQuickActionSheetChrome.sheetScrollContentTopInset)
                .padding(.bottom, DesignTokens.spacingLG)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: PantryQuickActionSheetHeightKey.self, value: proxy.size.height)
                    }
                )
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.pantryQuickActionSheet
                .ignoresSafeArea(edges: [.horizontal, .bottom])
        )
        .onPreferenceChange(PantryQuickActionSheetHeightKey.self) { newValue in
            guard newValue > 1 else { return }
            if abs(newValue - measuredContentHeight) > 0.5 {
                measuredContentHeight = newValue
            }
        }
        .modifier(PantryQuickActionSheetPresentationModifier(detentHeight: detentHeight))
    }
}

struct PantryQuickActionSheetPresentationModifier: ViewModifier {
    let detentHeight: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .presentationSizing(.page)
                .presentationDetents([.height(detentHeight)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.pantryQuickActionSheet)
                .presentationCompactAdaptation(.none)
        } else {
            content
                .presentationDetents([.height(detentHeight)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.pantryQuickActionSheet)
                .presentationCompactAdaptation(.none)
        }
    }
}

// MARK: - Generate-style green sheet sections (shared by generate / web import / new cookbook)

struct PantryGenerateSheetFormSection<Content: View>: View {
    var title: String? = nil
    var subtitle: String? = nil
    /// When `false`, omit the trailing rule (e.g. last block before a shared primary CTA divider).
    var showsTrailingDivider: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                // Divider below already provides top inset; avoid stacking `spacingSM` here too.
                if let title = title {
                    PantryQuickActionSheetChrome.sectionHeader(title, isFirst: true)
                }
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.pantryBody)
                        .foregroundStyle(Color.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsTrailingDivider {
                PantryQuickActionSheetChrome.generateSheetSectionDivider
            }
        }
    }
}

// MARK: - Generate Recipes sheet (green, same detent / page sizing as quick actions)

struct PantryGenerateRecipeSheetShell<Inner: View>: View {
    var minDetentHeight: CGFloat = 380
    /// Sheet chrome background (e.g. brand green or white for light sheets).
    var sheetBackground: Color = Color.pantryGenerateRecipeSheet
    /// Horizontal inset for scroll content (defaults match other green generate sheets).
    var horizontalContentPadding: CGFloat = LayoutHelpers.quickActionSheetHorizontalPadding
    /// Extra space below scroll content before the sheet edge.
    var bottomContentPadding: CGFloat = DesignTokens.spacingLG
    @ViewBuilder var inner: () -> Inner

    @State private var measuredContentHeight: CGFloat = 0

    private var maxSheetHeight: CGFloat {
        UIScreen.main.bounds.height * 0.92
    }

    private var detentHeight: CGFloat {
        let minH = minDetentHeight
        guard measuredContentHeight > 1 else { return minH }
        return min(max(measuredContentHeight, minH), maxSheetHeight)
    }

    var body: some View {
        ScrollView {
            inner()
                .padding(.horizontal, horizontalContentPadding)
                .padding(.top, PantryQuickActionSheetChrome.sheetScrollContentTopInset)
                .padding(.bottom, bottomContentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: PantryQuickActionSheetHeightKey.self, value: proxy.size.height)
                    }
                )
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            sheetBackground
                .ignoresSafeArea(edges: [.horizontal, .bottom])
        )
        .onPreferenceChange(PantryQuickActionSheetHeightKey.self) { newValue in
            guard newValue > 1 else { return }
            if abs(newValue - measuredContentHeight) > 0.5 {
                measuredContentHeight = newValue
            }
        }
        .modifier(PantryGenerateRecipeSheetPresentationModifier(detentHeight: detentHeight, sheetBackground: sheetBackground))
    }
}

struct PantryGenerateRecipeSheetPresentationModifier: ViewModifier {
    let detentHeight: CGFloat
    let sheetBackground: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .presentationSizing(.page)
                .presentationDetents([.height(detentHeight)])
                .presentationDragIndicator(.visible)
                .presentationBackground(sheetBackground)
                .presentationCompactAdaptation(.none)
        } else {
            content
                .presentationDetents([.height(detentHeight)])
                .presentationDragIndicator(.visible)
                .presentationBackground(sheetBackground)
                .presentationCompactAdaptation(.none)
        }
    }
}

struct PantryGenerateWizardShell<Inner: View>: View {
    var sheetBackground: Color = Color.pantryGenerateRecipeSheet
    var horizontalContentPadding: CGFloat = LayoutHelpers.quickActionSheetHorizontalPadding
    
    let currentPage: Int
    let totalPages: Int
    let title: String
    let onBack: () -> Void
    let onCancel: () -> Void
    let footerButtonTitle: String
    let footerButtonAction: () -> Void
    let isFooterButtonDisabled: Bool
    var isFooterButtonLoading: Bool = false
    var showSparklesOnLastPage: Bool = true
    
    @ViewBuilder var inner: () -> Inner

    private var progress: CGFloat {
        if totalPages <= 1 { return 1.0 }
        return CGFloat(currentPage + 1) / CGFloat(totalPages)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top Chrome
            VStack(spacing: DesignTokens.spacingSM) {
                HStack {
                    Button {
                        HapticFeedback.light()
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(.pantrySubheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.white.opacity(0.95))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, LayoutHelpers.quickActionSheetHorizontalPadding)
                .padding(.top, DesignTokens.spacingLG)
                .padding(.bottom, DesignTokens.spacingXS)
                
                HStack(spacing: DesignTokens.spacingMD) {
                    if totalPages > 1 {
                        Button {
                            HapticFeedback.light()
                            if currentPage > 0 {
                                onBack()
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
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }

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

                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, LayoutHelpers.quickActionSheetHorizontalPadding)
                .padding(.bottom, DesignTokens.spacingSM)
                
                PantryQuickActionSheetChrome.sheetTitle(title)
                    .padding(.horizontal, LayoutHelpers.quickActionSheetHorizontalPadding)
                    // override the default bottom padding to make it tight with the scrollview
                    .padding(.bottom, DesignTokens.spacingXS)
            }
            .background(sheetBackground)
            
            // Scrollable Content
            ScrollView {
                inner()
                    .padding(.horizontal, horizontalContentPadding)
                    .padding(.top, DesignTokens.spacingSM)
                    .padding(.bottom, DesignTokens.spacingLG)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Bottom Chrome
            VStack(spacing: 0) {
                Button {
                    HapticFeedback.medium()
                    footerButtonAction()
                } label: {
                    HStack(spacing: 10) {
                        if isFooterButtonLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.pantryPrimary))
                        } else if currentPage == totalPages - 1 && showSparklesOnLastPage {
                            Image(systemName: "sparkles")
                                .font(.pantryHeadline)
                                .foregroundStyle(Color.pantryPrimary)
                        } else if totalPages == 1 && !showSparklesOnLastPage {
                             Image(systemName: "network")
                                 .font(.pantryCustom(size: 16, weight: .semibold))
                                 .foregroundStyle(Color.pantryPrimary)
                        }
                        
                        Text(isFooterButtonLoading ? "Scanning…" : footerButtonTitle)
                            .font(.pantryHeadline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.pantryPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: DesignTokens.buttonHeightLarge)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusLarge, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isFooterButtonDisabled || isFooterButtonLoading)
                .opacity((isFooterButtonDisabled || isFooterButtonLoading) ? 0.55 : 1)
                .padding(.horizontal, LayoutHelpers.quickActionSheetHorizontalPadding)
                .padding(.top, DesignTokens.spacingSM)
                .padding(.bottom, DesignTokens.spacingLG)
            }
            .background(sheetBackground)
        }
        .background(sheetBackground.ignoresSafeArea(edges: [.horizontal, .bottom]))
        .modifier(PantryGenerateWizardSheetPresentationModifier(sheetBackground: sheetBackground))
    }
}

// MARK: - Flow Layout (wrapping chips/pills)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            var frames: [CGRect] = []
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.frames = frames
            self.size = CGSize(
                width: maxWidth,
                height: max(0, currentY + lineHeight)
            )
        }
    }
}

// MARK: - Pantry Pill Button (shared by Pantry / Plan / etc)

struct PantryPillButton: View {
    let title: String
    let tint: Color
    var isExpanded: Bool = false
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let fillOpacity = colorScheme == .dark ? 0.26 : 0.16
        let strokeOpacity = colorScheme == .dark ? 0.45 : 0.32

        Button(action: action) {
            Text(title)
                .font(.pantrySubheadline)
                .fontWeight(.semibold)
                .foregroundColor(.pantryTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(tint.opacity(fillOpacity))
                )
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(strokeOpacity), lineWidth: 1)
                )
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(isExpanded ? "Expanded. Double tap to collapse." : "Collapsed. Double tap to expand.")
    }
}

// MARK: - Option Chip Component
struct OptionChip: View {
    enum VisualStyle {
        case standard
        /// White / frosted chips on green generate sheet.
        case generateSheet
    }

    enum ChipSize {
        case standard
        case large
    }

    let option: OptionItem
    let isSelected: Bool
    var style: VisualStyle = .standard
    var size: ChipSize = .standard
    var isFullWidth: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            switch style {
            case .standard:
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    onTap()
                }
            case .generateSheet:
                withAnimation(.easeInOut(duration: 0.18)) {
                    onTap()
                }
            }
        }) {
            HStack(spacing: size == .large ? 10 : 5) {
                if option.icon.count == 1 {
                    Text(option.icon).font(size == .large ? .pantryTitle3 : .pantrySubheadline)
                        .frame(width: size == .large ? 32 : 24, alignment: .center)
                } else {
                    Image(systemName: option.icon)
                        .font(size == .large ? .pantryBody.weight(.medium) : .pantryCaption)
                        .frame(width: size == .large ? 32 : 24, alignment: .center)
                }
                Text(option.name)
                    .font(size == .large ? .pantryBody : .pantrySubheadline)
                    .fontWeight(.medium)
                
                if isFullWidth {
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.pantrySubheadline.weight(.bold))
                    }
                }
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil, alignment: .leading)
            .padding(.horizontal, size == .large ? 16 : 12)
            .padding(.vertical, size == .large ? 14 : 8)
            .background(chipBackground)
            .foregroundStyle(chipForeground)
            .clipShape(RoundedRectangle(cornerRadius: chipCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: chipCornerRadius, style: .continuous)
                    .stroke(chipStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var chipCornerRadius: CGFloat {
        switch (style, size) {
        case (.generateSheet, .large):
            return 12
        case (.generateSheet, .standard):
            return 10
        case (.standard, .large):
            return 20
        case (.standard, .standard):
            return 18
        }
    }

    private var chipBackground: Color {
        switch style {
        case .standard:
            return isSelected ? Color.pantryPrimary.opacity(0.92) : Color.pantryBackground
        case .generateSheet:
            return isSelected ? Color.white : Color.white.opacity(0.16)
        }
    }

    private var chipForeground: Color {
        switch style {
        case .standard:
            return isSelected ? Color.white : Color.pantryTextPrimary
        case .generateSheet:
            return isSelected ? Color.pantryPrimary : Color.white
        }
    }

    private var chipStroke: Color {
        switch style {
        case .standard:
            return isSelected ? Color.pantryPrimary.opacity(0.2) : Color.pantryBorderSubtle
        case .generateSheet:
            return isSelected ? Color.white.opacity(0.35) : Color.white.opacity(0.32)
        }
    }
}

struct PantryGenerateWizardSheetPresentationModifier: ViewModifier {
    let sheetBackground: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .presentationSizing(.page)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(sheetBackground)
                .presentationCompactAdaptation(.none)
        } else {
            content
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(sheetBackground)
                .presentationCompactAdaptation(.none)
        }
    }
}

// MARK: - Grocery list export (share sheet + analytics on completed share)

private enum GroceryListShareRowMetrics {
    static let verticalPadding: CGFloat = 14
}

private struct GroceryListShareRow: View {
    let exportBody: String
    let listIsEmpty: Bool
    @State private var showShareSheet = false

    var body: some View {
        if listIsEmpty {
            HStack(alignment: .center, spacing: DesignTokens.spacingSM) {
                Text("Export Grocery List")
                    .font(.pantryTitle3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.white.opacity(0.42))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Image(systemName: "square.and.arrow.up")
                    .font(.pantryTitle3.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .padding(.vertical, GroceryListShareRowMetrics.verticalPadding)
            .contentShape(Rectangle())
            .allowsHitTesting(false)
            .accessibilityLabel("Export Grocery List, list is empty")
        } else {
            Button {
                HapticFeedback.medium()
                showShareSheet = true
            } label: {
                HStack(alignment: .center, spacing: DesignTokens.spacingSM) {
                    Text("Export Grocery List")
                        .font(.pantryTitle3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 12)
                    Image(systemName: "square.and.arrow.up")
                        .font(.pantryTitle3.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.95))
                }
                .padding(.vertical, GroceryListShareRowMetrics.verticalPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Export Grocery List")
            .sheet(isPresented: $showShareSheet) {
                GroceryListActivitySheet(text: exportBody) { completed in
                    showShareSheet = false
                    if completed {
                        AppAnalytics.logGroceryListShared()
                    }
                }
            }
        }
    }
}

/// Presents `UIActivityViewController` so we can log when the user completes a share (not just opens the sheet).
private struct GroceryListActivitySheet: UIViewControllerRepresentable {
    let text: String
    var onFinish: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            DispatchQueue.main.async {
                onFinish(completed)
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
