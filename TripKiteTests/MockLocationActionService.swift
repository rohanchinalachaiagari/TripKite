import Foundation
@testable import TripKite

@MainActor
final class MockLocationActionService: LocationActionService {
    struct OpenInMapsCall: Equatable {
        let name: String
        let address: String
    }

    private(set) var openInMapsCalls: [OpenInMapsCall] = []
    private(set) var copyCalls: [String] = []

    func openInMaps(name: String, address: String) {
        openInMapsCalls.append(OpenInMapsCall(name: name, address: address))
    }

    func copy(text: String) {
        copyCalls.append(text)
    }

    func reset() {
        openInMapsCalls.removeAll()
        copyCalls.removeAll()
    }
}
