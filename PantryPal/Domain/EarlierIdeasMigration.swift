//
//  EarlierIdeasMigration.swift
//  Reciplease
//
//  Moves legacy Uncategorized membership into an inbox without deleting recipes.
//

import Foundation

struct CookbookSnapshot: Equatable {
    var id: UUID
    var name: String
    var recipeIds: [UUID]
    var createdAt: Date
    var isDefaultFavorites: Bool
    var isDefaultUncategorized: Bool
    var isInbox: Bool

    init(
        id: UUID,
        name: String,
        recipeIds: [UUID],
        createdAt: Date,
        isDefaultFavorites: Bool,
        isDefaultUncategorized: Bool,
        isInbox: Bool = false
    ) {
        self.id = id
        self.name = name
        self.recipeIds = recipeIds
        self.createdAt = createdAt
        self.isDefaultFavorites = isDefaultFavorites
        self.isDefaultUncategorized = isDefaultUncategorized
        self.isInbox = isInbox
    }
}

enum EarlierIdeasMigration {
    static let inboxName = "Earlier Ideas"
    static let migrationDefaultsKey = "Reciplease.EarlierIdeasMigration.v1"

    struct Result {
        var cookbooks: [CookbookSnapshot]
        var changed: Bool
    }

    static func migrate(_ cookbooks: [CookbookSnapshot], now: Date = Date()) -> Result {
        guard let uncategorizedIndex = cookbooks.firstIndex(where: { $0.isDefaultUncategorized }) else {
            return Result(cookbooks: cookbooks, changed: false)
        }
        let moving = cookbooks[uncategorizedIndex].recipeIds
        guard !moving.isEmpty else {
            return Result(cookbooks: cookbooks, changed: false)
        }

        var next = cookbooks
        next[uncategorizedIndex].recipeIds = []

        if let inboxIndex = next.firstIndex(where: { $0.isInbox || $0.name.caseInsensitiveCompare(inboxName) == .orderedSame }) {
            var seen = Set(next[inboxIndex].recipeIds)
            for id in moving where seen.insert(id).inserted {
                next[inboxIndex].recipeIds.append(id)
            }
            next[inboxIndex].isInbox = true
            if next[inboxIndex].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                next[inboxIndex].name = inboxName
            }
        } else {
            let inbox = CookbookSnapshot(
                id: UUID(),
                name: inboxName,
                recipeIds: moving,
                createdAt: now,
                isDefaultFavorites: false,
                isDefaultUncategorized: false,
                isInbox: true
            )
            let insertAt = min(uncategorizedIndex + 1, next.count)
            next.insert(inbox, at: insertAt)
        }

        var seen = Set<UUID>()
        for index in next.indices {
            next[index].recipeIds = next[index].recipeIds.filter { seen.insert($0).inserted }
        }
        return Result(cookbooks: next, changed: true)
    }
}
