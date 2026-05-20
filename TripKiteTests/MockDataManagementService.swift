import Foundation
@testable import TripKite

actor MockDataManagementService: DataManagementService {
    private(set) var clearCallCount = 0
    var clearError: Error?

    func setClearError(_ error: Error?) {
        clearError = error
    }

    func clearAllData() async throws {
        clearCallCount += 1
        if let clearError {
            throw clearError
        }
    }
}
