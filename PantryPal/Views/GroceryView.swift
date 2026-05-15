//
//  GroceryView.swift
//  PantryPal
//
//  Grocery list: pantry-style list, manual add row, checkboxes, bulk actions.
//

import SwiftUI
import UIKit

private enum GroceryRowField: Hashable {
    case name, quantity
}

struct GroceryView: View {
    @ObservedObject var viewModel: PantryViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var isRequestingInstacart = false
    @State private var instacartErrorMessage: String?

    private var sortedGroceryItems: [GroceryListItem] {
        let unchecked = viewModel.groceryItems.filter { !$0.isChecked }.sorted { $0.createdAt < $1.createdAt }
        let checked = viewModel.groceryItems.filter(\.isChecked).sorted { $0.createdAt < $1.createdAt }
        return unchecked + checked
    }

    private var uncheckedItems: [(name: String, quantity: String)] {
        viewModel.groceryItems
            .filter { !$0.isChecked }
            .sorted { $0.createdAt < $1.createdAt }
            .map { (name: $0.name, quantity: $0.quantity) }
    }

    private var hasUncheckedItems: Bool { !uncheckedItems.isEmpty }

    private var hasCheckedItems: Bool {
        viewModel.groceryItems.contains(where: \.isChecked)
    }

    private var allItemsChecked: Bool {
        !viewModel.groceryItems.isEmpty && viewModel.groceryItems.allSatisfy(\.isChecked)
    }

    private var formattedGroceryListForExport: String {
        viewModel.formattedGroceryListForExport()
    }

    var body: some View {
        List {
            groceryPillsRow
                .padding(.top, 4)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 6, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            AddGroceryItemInPlaceRow(viewModel: viewModel)
                .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
                .listRowSeparator(.visible, edges: .bottom)
                .listRowSeparatorTint(Color.pantryBorder.opacity(0.45))
                .listRowBackground(Color.clear)

            ForEach(sortedGroceryItems) { item in
                GroceryItemInPlaceRow(viewModel: viewModel, item: item)
                    .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
                    .listRowSeparator(.visible, edges: .bottom)
                    .listRowSeparatorTint(Color.pantryBorder.opacity(0.45))
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            HapticFeedback.medium()
                            withAnimation {
                                viewModel.removeGroceryItem(id: item.id)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .mainTabRootNavigationChrome(
            title: MainTabNavigationCopy.groceryNavigationTitle(itemCount: viewModel.groceryItems.count)
        )
        .background(Color.pantryBackground)
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            }
        }
        .alert("Instacart", isPresented: .constant(instacartErrorMessage != nil)) {
            Button("OK") { instacartErrorMessage = nil }
        } message: {
            if let message = instacartErrorMessage {
                Text(message)
            }
        }
    }

    private func orderOnInstacart() {
        let items = uncheckedItems
        guard !items.isEmpty else { return }
        isRequestingInstacart = true
        Task {
            defer { isRequestingInstacart = false }
            do {
                let url = try await UserService.shared.fetchInstacartShoppingListURL(items: items)
                await UIApplication.shared.open(url)
            } catch {
                instacartErrorMessage = (error as? LocalizedError)?.errorDescription
                    ?? "Something went wrong. Please try again."
            }
        }
    }

    private var groceryPillsRow: some View {
        FlowLayout(spacing: 8) {
            groceryExportPill
            // groceryInstacartPill  // TODO: re-enable once backend is ready
            groceryActionPill(title: "Check All", tint: .pantrySecondary, enabled: !viewModel.groceryItems.isEmpty && !allItemsChecked) {
                viewModel.checkAllGroceryItems()
            }
            groceryActionPill(title: "Uncheck All", tint: .pantryPrimary, enabled: hasCheckedItems) {
                viewModel.uncheckAllGroceryItems()
            }
            groceryActionPill(title: "Clear", tint: .pantryPrimary, enabled: hasCheckedItems) {
                viewModel.clearCheckedGroceryItems()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var instacartGreen: Color { Color(red: 0.263, green: 0.690, blue: 0.165) }

    private var groceryInstacartPill: some View {
        let fillOpacity = colorScheme == .dark ? 0.26 : 0.16
        let strokeOpacity = colorScheme == .dark ? 0.45 : 0.32
        let enabled = hasUncheckedItems && !isRequestingInstacart
        let tint = instacartGreen

        return Button {
            guard enabled else { return }
            HapticFeedback.medium()
            orderOnInstacart()
        } label: {
            HStack(spacing: 6) {
                if isRequestingInstacart {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: tint))
                        .scaleEffect(0.75)
                } else {
                    Text("Instacart")
                        .font(.pantrySubheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(hasUncheckedItems ? Color.pantryTextPrimary : Color.pantryTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(tint.opacity(hasUncheckedItems ? fillOpacity : fillOpacity * 0.35))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(hasUncheckedItems ? strokeOpacity : strokeOpacity * 0.4), lineWidth: 1)
            )
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel("Order on Instacart")
    }

    private var groceryExportPill: some View {
        let fillOpacity = colorScheme == .dark ? 0.26 : 0.16
        let strokeOpacity = colorScheme == .dark ? 0.45 : 0.32
        let enabled = !viewModel.groceryItems.isEmpty
        let tint = Color.pantrySecondary

        return Group {
            if enabled {
                ShareLink(
                    item: formattedGroceryListForExport,
                    subject: Text("Grocery list"),
                    message: Text("From Reciplease")
                ) {
                    groceryPillLabel(title: "Export", tint: tint, fillOpacity: fillOpacity, strokeOpacity: strokeOpacity, foregroundEnabled: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Export grocery list")
            } else {
                groceryActionPill(title: "Export", tint: tint, enabled: false) {}
            }
        }
    }

    private func groceryPillLabel(title: String, tint: Color, fillOpacity: CGFloat, strokeOpacity: CGFloat, foregroundEnabled: Bool) -> some View {
        Text(title)
            .font(.pantrySubheadline)
            .fontWeight(.semibold)
            .foregroundColor(foregroundEnabled ? Color.pantryTextPrimary : Color.pantryTextSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(tint.opacity(foregroundEnabled ? fillOpacity : fillOpacity * 0.35))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(foregroundEnabled ? strokeOpacity : strokeOpacity * 0.4), lineWidth: 1)
            )
            .fixedSize(horizontal: true, vertical: false)
    }

    private func groceryActionPill(title: String, tint: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        let fillOpacity = colorScheme == .dark ? 0.26 : 0.16
        let strokeOpacity = colorScheme == .dark ? 0.45 : 0.32

        return Button {
            guard enabled else { return }
            HapticFeedback.light()
            action()
        } label: {
            groceryPillLabel(title: title, tint: tint, fillOpacity: fillOpacity, strokeOpacity: strokeOpacity, foregroundEnabled: enabled)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(title)
    }

    /// Tighter gap between the leading checkbox/plus column and the ingredient emoji.
    fileprivate static let checkboxToIconSpacing: CGFloat = 6
}

// MARK: - Add row

private struct AddGroceryItemInPlaceRow: View {
    @ObservedObject var viewModel: PantryViewModel

    @State private var name = ""
    @State private var quantity = ""
    @State private var errorMessage: String?
    @FocusState private var focusedField: GroceryRowField?

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { name },
            set: { newValue in
                if newValue.count <= AppConfig.maxIngredientNameLength {
                    name = newValue
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: GroceryView.checkboxToIconSpacing) {
                Group {
                    if trimmedName.isEmpty {
                        Image(systemName: "plus")
                            .font(.pantryCustom(size: 22, weight: .regular))
                            .foregroundColor(.pantryTextSecondary)
                    } else {
                        IngredientPantryLeadingIcon(icon: getIngredientIcon(for: trimmedName))
                    }
                }
                .frame(width: PantryIngredientListMetrics.iconColumnWidth, alignment: .center)

                VStack(alignment: .leading, spacing: 0) {
                    TextField("Item name", text: nameBinding)
                        .textFieldStyle(.plain)
                        .font(.pantryBody)
                        .fontWeight(.bold)
                        .foregroundColor(.pantryTextPrimary)
                        .lineLimit(1)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .quantity }

                    TextField("Quantity", text: $quantity)
                        .textFieldStyle(.plain)
                        .font(.pantrySubheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.pantrySecondary)
                        .lineLimit(1)
                        .padding(.top, -4)
                        .focused($focusedField, equals: .quantity)
                        .submitLabel(.done)
                        .onSubmit { commitAdd() }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.pantryCaption2)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, PantryIngredientListMetrics.rowVPadding)
        .onChange(of: focusedField) { _, new in
            if new == nil {
                attemptCommitOnBlur()
            }
        }
    }

    private func attemptCommitOnBlur() {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        commitAdd()
    }

    private func commitAdd() {
        errorMessage = nil
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        let before = viewModel.groceryItems.count
        viewModel.addGroceryItem(name: n, quantity: quantity)
        if viewModel.groceryItems.count > before {
            HapticFeedback.success()
            name = ""
            quantity = ""
            focusedField = nil
        }
    }
}

// MARK: - Item row

private struct GroceryItemInPlaceRow: View {
    @ObservedObject var viewModel: PantryViewModel
    let item: GroceryListItem

    @State private var name: String
    @State private var quantity: String
    @FocusState private var focusedField: GroceryRowField?

    init(viewModel: PantryViewModel, item: GroceryListItem) {
        self.viewModel = viewModel
        self.item = item
        _name = State(initialValue: item.name)
        _quantity = State(initialValue: item.quantity)
    }

    private var liveItem: GroceryListItem? {
        viewModel.groceryItems.first(where: { $0.id == item.id })
    }

    private var isChecked: Bool {
        liveItem?.isChecked ?? item.isChecked
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { name },
            set: { newValue in
                if newValue.count <= AppConfig.maxIngredientNameLength {
                    name = newValue
                }
            }
        )
    }

    private var nameColor: Color {
        isChecked ? Color.pantryTextSecondary.opacity(0.55) : Color.pantryTextPrimary
    }

    private var quantityColor: Color {
        isChecked ? Color.pantryTextSecondary.opacity(0.45) : Color.pantrySecondary
    }

    private var iconNameKey: String {
        let k = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return k.isEmpty ? (liveItem?.name ?? item.name) : k
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: GroceryView.checkboxToIconSpacing) {
                Button {
                    HapticFeedback.light()
                    viewModel.toggleGroceryItemChecked(id: item.id)
                } label: {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.pantryTitle3)
                        .foregroundStyle(isChecked ? Color.pantryTextSecondary.opacity(0.55) : Color.pantryPrimary)
                        .frame(width: PantryIngredientListMetrics.iconColumnWidth, alignment: .center)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isChecked ? "Marked as got" : "Mark as got")

                IngredientPantryLeadingIcon(icon: getIngredientIcon(for: iconNameKey))
                    .opacity(isChecked ? 0.45 : 1)

                VStack(alignment: .leading, spacing: 0) {
                    TextField("Item name", text: nameBinding)
                        .textFieldStyle(.plain)
                        .font(.pantryBody)
                        .fontWeight(.bold)
                        .foregroundColor(nameColor)
                        .strikethrough(isChecked, pattern: .solid, color: .pantryTextSecondary.opacity(0.45))
                        .lineLimit(1)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .quantity }

                    TextField("Quantity", text: $quantity)
                        .textFieldStyle(.plain)
                        .font(.pantrySubheadline)
                        .fontWeight(.medium)
                        .foregroundColor(quantityColor)
                        .strikethrough(isChecked, pattern: .solid, color: .pantryTextSecondary.opacity(0.35))
                        .lineLimit(1)
                        .padding(.top, -4)
                        .focused($focusedField, equals: .quantity)
                        .submitLabel(.done)
                        .onSubmit { commitIfDirty() }
                }
            }
        }
        .padding(.vertical, PantryIngredientListMetrics.rowVPadding)
        .onChange(of: liveItem) { _, new in
            guard focusedField == nil, let new else { return }
            name = new.name
            quantity = new.quantity
        }
        .onChange(of: focusedField) { _, new in
            if new == nil {
                commitIfDirty()
            }
        }
    }

    private func commitIfDirty() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            name = liveItem?.name ?? item.name
            quantity = liveItem?.quantity ?? item.quantity
            return
        }
        if trimmedName != (liveItem?.name ?? item.name) || quantity != (liveItem?.quantity ?? item.quantity) {
            viewModel.updateGroceryItem(id: item.id, name: trimmedName, quantity: quantity)
        }
    }
}

#Preview {
    NavigationStack {
        GroceryView(viewModel: PantryViewModel())
    }
}
