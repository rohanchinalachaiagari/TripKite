import Foundation

enum ReminderOption: CaseIterable, Identifiable, Hashable {
    case none
    case atStart
    case minutesBefore5
    case minutesBefore15
    case minutesBefore30
    case hourBefore1
    case dayBefore1

    var id: Self { self }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .atStart: return "At start time"
        case .minutesBefore5: return "5 minutes before"
        case .minutesBefore15: return "15 minutes before"
        case .minutesBefore30: return "30 minutes before"
        case .hourBefore1: return "1 hour before"
        case .dayBefore1: return "1 day before"
        }
    }

    var offset: TimeInterval? {
        switch self {
        case .none: return nil
        case .atStart: return 0
        case .minutesBefore5: return 5 * 60
        case .minutesBefore15: return 15 * 60
        case .minutesBefore30: return 30 * 60
        case .hourBefore1: return 60 * 60
        case .dayBefore1: return 24 * 60 * 60
        }
    }

    // V1: only preset offsets are supported. Stored offsets that don't match a
    // preset fall back to .none — caller logic preserves the underlying value
    // by passing it through as-is on save unless the picker is touched.
    static func match(offset: TimeInterval?) -> ReminderOption {
        guard let offset else { return .none }
        return ReminderOption.allCases.first { $0.offset == offset } ?? .none
    }
}
