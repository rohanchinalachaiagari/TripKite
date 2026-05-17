import Foundation

enum ItineraryValidationError: LocalizedError, Equatable {
    case missingTitle
    case endDateBeforeStartDate

    var errorDescription: String? {
        switch self {
        case .missingTitle:
            return "Please enter a title for this item."
        case .endDateBeforeStartDate:
            return "The end time cannot be before the start time."
        }
    }
}

enum ItineraryValidator {
    // V1 hard rules:
    //   - title cannot be empty
    //   - if endDate is set, it cannot be before startDate
    // TODO (future): soft warning when startDate falls outside the parent trip's range.
    static func validate(
        title: String,
        startDate: Date,
        endDate: Date?
    ) throws {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ItineraryValidationError.missingTitle
        }
        if let endDate, endDate < startDate {
            throw ItineraryValidationError.endDateBeforeStartDate
        }
    }
}
