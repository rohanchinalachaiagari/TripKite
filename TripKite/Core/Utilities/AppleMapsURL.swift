import Foundation

// Builds a maps.apple.com search URL from free-text location fields. Pure
// function: no UIKit, no MapKit, no geocoding. Apple Maps resolves the
// resulting URL inside the Maps app — when both fields are present, `address`
// drives the geocoded pin location and `q` drives the pin label.
enum AppleMapsURL {
    static func searchURL(name: String, address: String) -> URL? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

        var components = URLComponents()
        components.scheme = "https"
        components.host = "maps.apple.com"

        var items: [URLQueryItem] = []
        if !trimmedAddress.isEmpty {
            if !trimmedName.isEmpty {
                items.append(URLQueryItem(name: "q", value: trimmedName))
            }
            items.append(URLQueryItem(name: "address", value: trimmedAddress))
        } else if !trimmedName.isEmpty {
            items.append(URLQueryItem(name: "q", value: trimmedName))
        } else {
            return nil
        }

        components.queryItems = items
        return components.url
    }
}
