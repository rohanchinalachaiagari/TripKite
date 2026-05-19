import Foundation

enum TripValidationError: LocalizedError, Equatable {
    case missingTitle
    case missingDestination
    case endDateBeforeStartDate

    var errorDescription: String? {
        switch self {
        case .missingTitle:
            return "Please enter a trip title."
        case .missingDestination:
            return "Please enter a destination."
        case .endDateBeforeStartDate:
            return "The end date cannot be before the start date."
        }
    }
}

enum TripValidator {
    static func validate(
        title: String,
        destination: String,
        startDate: Date,
        endDate: Date
    ) throws {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TripValidationError.missingTitle
        }
        if destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TripValidationError.missingDestination
        }
        if endDate < startDate {
            throw TripValidationError.endDateBeforeStartDate
        }
    }
}
