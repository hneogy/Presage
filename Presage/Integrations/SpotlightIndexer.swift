import CoreSpotlight
import Foundation

enum SpotlightIndexer {
    static let domain = "com.pari.neogy.predictions"

    static func index(_ prediction: Prediction) async {
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

        try? await CSSearchableIndex.default().indexSearchableItems([item])
    }

    static func remove(_ predictionID: UUID) async {
        try? await CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: [predictionID.uuidString]
        )
    }

    static func reindexAll(_ predictions: [Prediction]) async {
        try? await CSSearchableIndex.default().deleteSearchableItems(
            withDomainIdentifiers: [domain]
        )
        for prediction in predictions {
            await index(prediction)
        }
    }
}
