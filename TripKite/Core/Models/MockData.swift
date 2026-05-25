import Foundation

#if DEBUG
enum MockData {
    private static let calendar = Calendar(identifier: .gregorian)

    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return calendar.date(from: components) ?? Date()
    }

    static let tokyoTrip = Trip(
        title: "Tokyo Adventure",
        destination: "Tokyo, Japan",
        startDate: date(2026, 8, 10),
        endDate: date(2026, 8, 20),
        notes: "First time in Japan. Cherry blossoms are out of season but excited for summer festivals."
    )

    static let lisbonTrip = Trip(
        title: "Lisbon Weekend",
        destination: "Lisbon, Portugal",
        startDate: date(2026, 5, 14),
        endDate: date(2026, 5, 18),
        notes: "Quick getaway with friends."
    )

    static let nycTrip = Trip(
        title: "NYC Long Weekend",
        destination: "New York, NY",
        startDate: date(2026, 3, 12),
        endDate: date(2026, 3, 16),
        notes: "Broadway shows and museum hopping."
    )

    static let banffTrip = Trip(
        title: "Banff Hiking",
        destination: "Banff, Canada",
        startDate: date(2026, 9, 22),
        endDate: date(2026, 9, 30),
        notes: "Need to book Lake Louise reservations."
    )

    // "Happening Now" trip — dates are anchored relative to the current
    // moment (computed once at first access) so previews and screenshots
    // always render a focus card without manual setup. Release builds never
    // see this because the whole file is #if DEBUG.
    static let activeTahoeTrip: Trip = {
        let now = Date()
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -2, to: now) ?? now
        let end = calendar.date(byAdding: .day, value: 4, to: now) ?? now
        return Trip(
            title: "Tahoe Long Weekend",
            destination: "Lake Tahoe, CA",
            startDate: start,
            endDate: end,
            notes: "Camping at Emerald Bay. Stargazing forecast looks clear."
        )
    }()

    static let trips: [Trip] = [tokyoTrip, lisbonTrip, nycTrip, banffTrip, activeTahoeTrip]

    static let tokyoItinerary: [ItineraryItem] = [
        ItineraryItem(
            tripId: tokyoTrip.id,
            title: "ANA NH 7 SFO → HND",
            type: .flight,
            startDate: date(2026, 8, 10, 11, 30),
            endDate: date(2026, 8, 11, 15, 5),
            locationName: "San Francisco International Airport",
            address: "780 S Airport Blvd, San Francisco, CA",
            confirmationNumber: "ANA-9X7K2L",
            notes: "Window seat, terminal I."
        ),
        ItineraryItem(
            tripId: tokyoTrip.id,
            title: "Park Hyatt Tokyo",
            type: .hotel,
            startDate: date(2026, 8, 11, 16, 0),
            endDate: date(2026, 8, 16, 11, 0),
            locationName: "Park Hyatt Tokyo",
            address: "3-7-1-2 Nishi Shinjuku, Shinjuku-ku, Tokyo",
            confirmationNumber: "HY-44820",
            notes: "Asked for high-floor room."
        ),
        ItineraryItem(
            tripId: tokyoTrip.id,
            title: "TeamLab Planets",
            type: .activity,
            startDate: date(2026, 8, 12, 10, 0),
            endDate: date(2026, 8, 12, 12, 30),
            locationName: "TeamLab Planets Tokyo",
            address: "6-1-16 Toyosu, Koto-ku, Tokyo",
            confirmationNumber: "TLP-22910"
        ),
        ItineraryItem(
            tripId: tokyoTrip.id,
            title: "Dinner at Sukiyabashi Jiro",
            type: .restaurant,
            startDate: date(2026, 8, 13, 18, 30),
            locationName: "Sukiyabashi Jiro Honten",
            address: "Tsukamoto Sogyo Building, 2-15 Ginza, Chuo-ku, Tokyo",
            confirmationNumber: "SJ-0813"
        ),
        ItineraryItem(
            tripId: tokyoTrip.id,
            title: "Shinkansen to Kyoto",
            type: .transportation,
            startDate: date(2026, 8, 16, 12, 0),
            endDate: date(2026, 8, 16, 14, 15),
            locationName: "Tokyo Station",
            confirmationNumber: "JR-KYO-118"
        ),
        ItineraryItem(
            tripId: tokyoTrip.id,
            title: "Pick up pocket Wi-Fi",
            type: .note,
            startDate: date(2026, 8, 11, 15, 30),
            notes: "Counter is past customs on the right."
        )
    ]

    static let lisbonItinerary: [ItineraryItem] = [
        ItineraryItem(
            tripId: lisbonTrip.id,
            title: "TAP TP 218 JFK → LIS",
            type: .flight,
            startDate: date(2026, 5, 14, 21, 30),
            endDate: date(2026, 5, 15, 9, 15),
            locationName: "John F. Kennedy International Airport",
            confirmationNumber: "TAP-LX9921"
        ),
        ItineraryItem(
            tripId: lisbonTrip.id,
            title: "Memmo Alfama",
            type: .hotel,
            startDate: date(2026, 5, 15, 14, 0),
            endDate: date(2026, 5, 18, 11, 0),
            locationName: "Memmo Alfama Hotel",
            address: "Travessa das Merceeiras 27, Lisboa",
            confirmationNumber: "MA-77123"
        ),
        ItineraryItem(
            tripId: lisbonTrip.id,
            title: "Tram 28 tour",
            type: .activity,
            startDate: date(2026, 5, 16, 10, 0),
            endDate: date(2026, 5, 16, 12, 0),
            locationName: "Martim Moniz Square"
        ),
        ItineraryItem(
            tripId: lisbonTrip.id,
            title: "Time Out Market",
            type: .restaurant,
            startDate: date(2026, 5, 16, 19, 0),
            locationName: "Time Out Market Lisboa",
            address: "Av. 24 de Julho 49, Lisboa"
        )
    ]

    static let activeTahoeItinerary: [ItineraryItem] = {
        let now = Date()
        return [
            ItineraryItem(
                tripId: activeTahoeTrip.id,
                title: "Sunrise hike at Eagle Falls",
                type: .activity,
                startDate: now.addingTimeInterval(-30 * 60),
                endDate: now.addingTimeInterval(75 * 60),
                locationName: "Eagle Falls Trailhead",
                address: "Emerald Bay, Lake Tahoe, CA"
            ),
            ItineraryItem(
                tripId: activeTahoeTrip.id,
                title: "Lunch at Sunnyside Lodge",
                type: .restaurant,
                startDate: now.addingTimeInterval(3 * 3600),
                locationName: "Sunnyside Restaurant & Lodge",
                address: "1850 W Lake Blvd, Tahoe City, CA"
            ),
            ItineraryItem(
                tripId: activeTahoeTrip.id,
                title: "Drive to Emerald Bay campground",
                type: .transportation,
                startDate: now.addingTimeInterval(6 * 3600),
                endDate: now.addingTimeInterval(7 * 3600),
                locationName: "Emerald Bay State Park",
                confirmationNumber: "TAHOE-EBP-77"
            )
        ]
    }()

    static let allItineraryItems: [ItineraryItem] = tokyoItinerary + lisbonItinerary + activeTahoeItinerary

    static func itineraryItems(for trip: Trip) -> [ItineraryItem] {
        allItineraryItems.filter { $0.tripId == trip.id }
    }
}
#endif
