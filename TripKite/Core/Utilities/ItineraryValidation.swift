import Foundation

enum ItineraryValidationError: LocalizedError, Equatable {
    case missingTitle
    case endDateBeforeStartDate
    case negativeReminderOffset

    var errorDescription: String? {
        switch self {
        case .missingTitle:
            return "Please enter a title for this item."
        case .endDateBeforeStartDate:
            return "The end time cannot be before the start time."
        case .negativeReminderOffset:
            return "Reminder time cannot be after the item starts."
        }
    }
}

enum ItineraryValidator {
    // Hard rules:
    //   - title cannot be empty
    //   - if endDate is set, it cannot be before startDate
    //   - if reminderOffset is set, it cannot be negative
    // The soft "outside trip range" warning is handled separately by the
    // editor view model via `pendingOutsideRangeConfirmation`.
    static func validate(
        title: String,
        startDate: Date,
        endDate: Date?,
        reminderOffset: TimeInterval? = nil
    ) throws {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ItineraryValidationError.missingTitle
        }
        if let endDate, endDate < startDate {
            throw ItineraryValidationError.endDateBeforeStartDate
        }
        if let reminderOffset, reminderOffset < 0 {
            throw ItineraryValidationError.negativeReminderOffset
        }
    }
}
