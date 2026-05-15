//
//  GenerationLimitSheet.swift
//  PantryPal
//
//  Quota summary for pantry generate / cookbook scan / web scan (weekly free, monthly Pro).
//

import SwiftUI

struct GenerationLimitSheet: View {
    @ObservedObject private var credits = GenerationCreditsManager.shared
    /// Dismiss this sheet, then present the full upgrade paywall from the parent.
    var onUnlockPro: () -> Void

    @ScaledMetric(relativeTo: .body) private var coinIconSize: CGFloat = 28

    private var displaySlots: Int {
        min(credits.maxCreditsForCurrentTier, 10)
    }

    var body: some View {
        PantryQuickActionSheetShell(minDetentHeight: 300) {
            VStack(alignment: .leading, spacing: 0) {
                PantryQuickActionSheetChrome.sheetTitle("Trial")

                if credits.isProSubscriber && credits.maxCreditsForCurrentTier > 10 {
                    Text("\(credits.remainingCredits) of \(credits.maxCreditsForCurrentTier)")
                        .font(.pantryTitle2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, DesignTokens.spacingSM)
                } else {
                    HStack(spacing: DesignTokens.spacingSM) {
                        ForEach(0..<displaySlots, id: \.self) { index in
                            BundleImage("avi_coin")
                                .scaledToFit()
                                .frame(width: coinIconSize, height: coinIconSize)
                                .opacity(index < credits.remainingCredits ? 1.0 : 0.28)
                        }
                    }
                    .padding(.vertical, DesignTokens.spacingSM)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(credits.remainingCredits) of \(credits.maxCreditsForCurrentTier) coins remaining")
                }

                Text(detailCopy)
                    .font(.pantryBody)
                    .foregroundStyle(Color.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, DesignTokens.spacingMD)

                PantryQuickActionSheetChrome.sectionDivider

                PantryQuickActionSheetChrome.actionRow(title: "Unlock more recipes", systemImage: "crown.fill", action: {
                    credits.dismissGenerationLimitSheet()
                    onUnlockPro()
                })

                PantryQuickActionSheetChrome.sectionDivider

                PantryQuickActionSheetChrome.actionRow(title: "Done", systemImage: "checkmark.circle.fill", action: {
                    credits.dismissGenerationLimitSheet()
                })
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var detailCopy: String {
        if credits.isProSubscriber {
            return "\(credits.remainingCredits) of \(credits.maxCreditsForCurrentTier) recipe generations and imports left this subscription period (pantry, cookbook pages, and web links)."
        }
        return "\(credits.remainingCredits) of \(credits.maxCreditsForCurrentTier) weekly recipe generations and imports left for pantry ideas, cookbook pages, and web links."
    }
}

#Preview {
    GenerationLimitSheet(onUnlockPro: {})
}
