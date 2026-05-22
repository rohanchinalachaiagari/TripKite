import XCTest
@testable import TripKite

final class AppleMapsURLTests: XCTestCase {

    func testSearchURL_BothFieldsPresent_UsesQNameAndAddressInOrder() {
        let url = AppleMapsURL.searchURL(
            name: "Park Hyatt Tokyo",
            address: "3-7-1-2 Nishi Shinjuku, Tokyo"
        )
        let components = components(for: url)
        XCTAssertEqual(components?.host, "maps.apple.com")
        XCTAssertEqual(components?.scheme, "https")
        XCTAssertEqual(
            components?.queryItems,
            [
                URLQueryItem(name: "q", value: "Park Hyatt Tokyo"),
                URLQueryItem(name: "address", value: "3-7-1-2 Nishi Shinjuku, Tokyo")
            ]
        )
    }

    func testSearchURL_AddressOnly_UsesAddressParameter() {
        let url = AppleMapsURL.searchURL(name: "", address: "221B Baker Street, London")
        let components = components(for: url)
        XCTAssertEqual(
            components?.queryItems,
            [URLQueryItem(name: "address", value: "221B Baker Street, London")]
        )
    }

    func testSearchURL_NameOnly_UsesQParameter() {
        let url = AppleMapsURL.searchURL(name: "Café de Flore", address: "")
        let components = components(for: url)
        XCTAssertEqual(
            components?.queryItems,
            [URLQueryItem(name: "q", value: "Café de Flore")]
        )
    }

    func testSearchURL_BothEmpty_ReturnsNil() {
        XCTAssertNil(AppleMapsURL.searchURL(name: "", address: ""))
    }

    func testSearchURL_BothWhitespaceOnly_ReturnsNil() {
        XCTAssertNil(AppleMapsURL.searchURL(name: "  \n ", address: "\t "))
    }

    func testSearchURL_TrimsLeadingTrailingWhitespace() {
        let url = AppleMapsURL.searchURL(name: "  Park Hyatt  ", address: " 3-7-1 Tokyo ")
        let components = components(for: url)
        XCTAssertEqual(
            components?.queryItems,
            [
                URLQueryItem(name: "q", value: "Park Hyatt"),
                URLQueryItem(name: "address", value: "3-7-1 Tokyo")
            ]
        )
    }

    func testSearchURL_PercentEncodesSpaces_AndLeavesCommasIntact() {
        let url = AppleMapsURL.searchURL(name: "", address: "1 Apple Park Way, Cupertino, CA")
        // URLQueryItem percent-encodes spaces as %20 but intentionally leaves
        // commas unescaped — `,` is a valid sub-delim in a URL query value per
        // RFC 3986. Apple Maps parses both forms; we just want to lock in the
        // observed behavior so a future change doesn't silently double-encode.
        let raw = url?.absoluteString ?? ""
        XCTAssertTrue(raw.contains("address=1%20Apple%20Park%20Way,%20Cupertino,%20CA"), raw)

        // The query value also round-trips through URLComponents to the
        // original string, regardless of how the raw URL is rendered.
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        XCTAssertEqual(
            components?.queryItems?.first(where: { $0.name == "address" })?.value,
            "1 Apple Park Way, Cupertino, CA"
        )
    }

    func testSearchURL_PercentEncodesUnicode() {
        let url = AppleMapsURL.searchURL(name: "Café de Flore", address: "")
        let raw = url?.absoluteString ?? ""
        // "é" is U+00E9, which percent-encodes to %C3%A9 in UTF-8.
        XCTAssertTrue(raw.contains("q=Caf%C3%A9%20de%20Flore"), raw)
    }

    func testSearchURL_AmpersandInAddress_IsEncodedNotInjected() {
        let url = AppleMapsURL.searchURL(name: "", address: "Tom & Jerry's Diner")
        let raw = url?.absoluteString ?? ""
        // The ampersand must be percent-encoded (%26) so it doesn't split into
        // two query parameters.
        XCTAssertTrue(raw.contains("address=Tom%20%26%20Jerry"), raw)
        // Exactly one address parameter.
        let components = components(for: url)
        XCTAssertEqual(components?.queryItems?.filter { $0.name == "address" }.count, 1)
    }

    // MARK: - Helpers

    private func components(for url: URL?) -> URLComponents? {
        guard let url else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)
    }
}
