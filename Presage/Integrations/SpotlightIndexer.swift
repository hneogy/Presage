import CoreSpotlight
import Foundation
import OSLog

private let spotlightLogger = Logger(subsystem: "com.pari.neogy", category: "Spotlight")

enum SpotlightIndexer {
    static let domain = "com.pari.neogy.predictions"

    /// User-controlled toggle. When OFF, predictions don't appear in
    /// Spotlight, Siri suggestions, or the iOS lock-screen search. The
    /// privacy-conscious default here is "on" because Spotlight
    /// integration is part of the product, but users with sensitive
    /// claims can disable it from Settings → Privacy → Spotlight.
    static var indexingEnabled: Bool {
        // Default to true if the user has never seen the toggle; once
        // they touch it, UserDefaults stores their choice.
        if UserDefaults.standard.object(forKey: "spotlightIndexingEnabled") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "spotlightIndexingEnabled")
    }

    static func index(_ prediction: Prediction) async {
        guard indexingEnabled else { return }

        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = prediction.claim
        attrs.contentDescription = "What counts as yes: \(prediction.resolutionCriteria)"
        attrs.keywords = [
            prediction.category.displayName,
            "prediction",
            "\(prediction.confidencePercent)%"
        ]
        attrs.identifier = prediction.id.uuidString
        attrs.relatedUniqueIdentifier = prediction.id.uuidString

        if prediction.isResolved {
            attrs.contentDescription = "\(prediction.outcome?.rawValue.capitalized ?? "—") · \(prediction.confidencePercent)%"
        }

        let item = CSSearchableItem(
            uniqueIdentifier: prediction.id.uuidString,
            domainIdentifier: domain,
            attributeSet: attrs
        )
        item.expirationDate = .distantFuture

        do {
            try await CSSearchableIndex.default().indexSearchableItems([item])
        } catch {
            spotlightLogger.error("Failed to index prediction \(prediction.id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Removes everything Pari has indexed. Call when the user toggles
    /// indexing off so existing entries don't linger in Spotlight.
    static func purgeAllIndexedContent() async {
        do {
            try await CSSearchableIndex.default().deleteSearchableItems(
                withDomainIdentifiers: [domain]
            )
            spotlightLogger.notice("Purged all Pari Spotlight entries (user toggled indexing off)")
        } catch {
            spotlightLogger.error("Failed to purge Spotlight: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func remove(_ predictionID: UUID) async {
        do {
            try await CSSearchableIndex.default().deleteSearchableItems(
                withIdentifiers: [predictionID.uuidString]
            )
        } catch {
            spotlightLogger.error("Failed to remove Spotlight entry for \(predictionID.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    static func reindexAll(_ predictions: [Prediction]) async {
        do {
            try await CSSearchableIndex.default().deleteSearchableItems(
                withDomainIdentifiers: [domain]
            )
        } catch {
            spotlightLogger.error("Failed to clear domain before reindex: \(error.localizedDescription, privacy: .public). Continuing — duplicates may surface until next clean reindex.")
        }
        for prediction in predictions {
            await index(prediction)
        }
        spotlightLogger.notice("Reindexed \(predictions.count) predictions")
    }
}
