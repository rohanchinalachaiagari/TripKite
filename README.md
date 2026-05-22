# TripKite

TripKite is an offline-first iOS travel companion built with SwiftUI and Core Data. It helps users create trips, build itineraries, attach travel documents, search across saved trip data, and open itinerary locations in Apple Maps. Everything works on-device without a network connection.

![Trip List](Screenshots/trip-list.png)

## Overview

TripKite is a focused iOS app for organizing personal travel. Users can create trips, add itinerary items (flights, hotels, activities, restaurants, transportation, notes), attach local documents, schedule local reminders for upcoming events, and search across everything they've saved. All data is stored on-device using Core Data and the app sandbox.

The project is a small surface area built with production-style engineering: clean architecture, protocol-based dependency injection, local persistence, testable view models, and offline-first behavior.

![Trip Detail](Screenshots/trip-detail.png)

## Motivation

Travel apps are a natural fit for offline-first design: connectivity is unpredictable exactly when an itinerary matters most. TripKite was built as a portfolio project that holds itself to the same constraints a real product would:

- Apple-native frameworks only. No third-party packages, no networking, no backend.
- Architecture shaped so cloud sync could be added later without a rewrite.
- A codebase small enough to read in a single sitting and complete enough to ship.

## Core Features

### Trips and itinerary
- Create, edit, and delete trips
- Add itinerary items with type, time, location, confirmation number, and notes
- Chronological timeline grouped by day
- "Happening Now" and "Up Next" focus card on the trip detail screen
- Confirmation prompt when an itinerary item falls outside the trip's date range

### Reminders
- Local reminders at preset offsets (5 min, 15 min, 30 min, 1 hour, 1 day, at start time)
- Foreground and background notification delivery
- Notification tap routes directly into the trip and item
- Default reminder preference in Settings

### Documents
- A global Documents tab with every attached file grouped by trip
- Attach PDFs, images, and screenshots from Files or Photos
- Optionally associate a document with a specific itinerary item
- QuickLook preview, rename, delete, and reassign
- Trip deletion cascades documents and sweeps files

### Search
- Substring search across trips, itinerary items, and documents
- Case-insensitive and diacritic-insensitive
- Tap a result to jump to the trip, item, or open the document
- All on-device, no index file

### Location actions
- For an itinerary item with an address or location name:
  - Open in Apple Maps
  - Copy address
  - Copy location name
- Inline copy buttons on the editor fields, plus a context menu on each timeline row

### Settings
- Default reminder preference
- Notification permission status with a link into iOS Settings
- Privacy summary
- Clear all data with destructive confirmation
- App version

## Technical Highlights

- **MVVM with protocol-based repositories.** View models depend on `TripRepository`, `ItineraryRepository`, `DocumentRepository`, `NotificationSchedulingService`, `DocumentStorageService`, `SearchService`, and `LocationActionService`. They never depend on Core Data, FileManager, UNUserNotificationCenter, UIApplication, or UIPasteboard directly.
- **Pure-Swift domain models.** `Trip`, `ItineraryItem`, and `TravelDocument` are `Sendable` value types with no framework dependencies. Core Data entities live behind `+Mapping` extensions.
- **Background Core Data contexts.** Every repository call runs on a fresh background context, so the main thread never blocks on disk I/O.
- **File / Core Data split for attachments.** File bytes live in the app sandbox; only metadata lives in Core Data, with a rollback path if the metadata write fails after the file copy.
- **Deterministic view models.** `@Sendable () -> Date` injection lets tests pin "now" and verify focus-card, status, and reminder behavior without flakiness.
- **MainActor bridging for notifications.** A `NotificationResponseHandler` bridges the `UNUserNotificationCenter` delegate callback (called on an arbitrary queue) to a `@MainActor`-isolated `AppRouter`.
- **Shared deep-link channel.** Notification taps and search-result taps both flow through `AppRouter.pendingTripDetail`, so the trip list has one routing seam instead of two.

## Architecture Overview

```text
SwiftUI View
    │
    ▼
ViewModel (@MainActor, ObservableObject)
    │
    ▼
Repository / Service protocol
    │
    ▼
Concrete implementation (Core Data / FileManager / UserNotifications / UIKit)
```

- Views are declarative and route user intent to view models.
- View models own presentation state, validation orchestration, and async coordination.
- Repositories abstract persistence; services abstract system capabilities (notifications, document storage, search, location actions).
- Domain logic that isn't presentation lives in standalone enums (`TripValidator`, `ItineraryValidator`, `ItineraryFocusResolver`, `ImageFormatDetection`, `AppleMapsURL`, `LocationActionAvailability`).
- `AppRouter` carries deep-link intent from notification taps and search-result taps into the navigation stack.

The dependency graph is constructed once in `TripKiteApp.init` and threaded down through initializers.

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI | SwiftUI, NavigationStack, TabView |
| State | `@StateObject` / `@ObservedObject`, `@MainActor` view models |
| Persistence | Core Data (background contexts) |
| Files | FileManager, sandboxed `Documents/Attachments/` |
| Notifications | UserNotifications (UNUserNotificationCenter, time-interval triggers) |
| Document preview | QuickLook (`QLPreviewController` wrapped in `UIViewControllerRepresentable`) |
| Pickers | PhotosUI, `fileImporter` |
| Maps | Apple Maps universal URL via `UIApplication.open` |
| Concurrency | Swift Concurrency (`async`/`await`, actor-isolated mocks) |
| Tests | XCTest |
| Min iOS | 17.6 |

No third-party packages.

## Core Data Persistence

The schema has three entities (`TripEntity`, `ItineraryItemEntity`, `TravelDocumentEntity`) connected by `Cascade` / `Nullify` rules so deletes behave correctly:

- Deleting a trip cascades to its items and document records.
- Deleting an item nullifies the relationship on associated documents. The document is preserved at trip level rather than vanishing.
- Deleting a document removes only its record (and, separately, the file on disk).

Each entity has a `UUID` `id` with a uniqueness constraint and `NSMergeByPropertyObjectTrumpMergePolicy` configured on every background context.

Repositories accept a `CoreDataStack` instance and never expose `NSManagedObject` to callers; mapping happens in `+Mapping` extensions that produce pure-Swift value types. This makes view models trivially testable with in-memory mocks.

```swift
protocol TripRepository: Sendable {
    func fetchTrips() async throws -> [Trip]
    func trip(with id: UUID) async throws -> Trip?
    func createTrip(_ trip: Trip) async throws
    func updateTrip(_ trip: Trip) async throws
    func deleteTrip(id: UUID) async throws
}
```

## Local Notifications and Reminders

Reminders are pure local notifications. The user picks a preset offset on the item editor (e.g. "15 minutes before"); the editor saves the item, then asks `NotificationSchedulingService` to cancel any prior reminder for that item id and schedule a fresh one.

The scheduling service builds an identifier of the form `trip-<tripId>-item-<itemId>`, which lets it cancel a single reminder by item id or every reminder for a trip on deletion.

Permission handling:

- Authorization is requested lazily. The first time the user changes the reminder picker away from "None."
- If the user denies, the editor surfaces an inline hint pointing them to Settings.
- Scheduling errors (e.g. the reminder time is already in the past) are non-fatal; the item still saves.

Foreground delivery is wired through the `UNUserNotificationCenterDelegate.willPresent` callback so reminders fire even when the app is open.

## Document Storage

Documents are split between Core Data and the file system:

- The file bytes (PDF, image, screenshot) are copied into `Documents/Attachments/` under a UUID-based filename.
- The `TravelDocumentEntity` records the display name, file type, file size, relative path, and optional `itineraryItemId` association.

Key behaviors:

- A 25 MB per-file cap, checked before copy when the size is reported and again on raw-data writes.
- Security-scoped URL bracketing for the document picker (`startAccessingSecurityScopedResource` / `stop`).
- Photo imports use magic-byte detection to choose `.png` vs `.jpg` vs `.heic` and pick a `Screenshot-` or `Photo-` prefix.
- If the metadata write fails after the file is copied, the file is rolled back so orphans aren't left on disk.
- Trip deletion fetches document paths before the cascade, then sweeps the files; per-file failures are non-fatal.

The global Documents tab groups every attached file by trip, with the same QuickLook preview, rename, delete, and reassign actions the per-trip section uses.

## Search

`SearchService` fans out to the three repositories in parallel and filters in memory using `localizedStandardContains`. Results are grouped by type (trips, itinerary items, documents) and sorted within each group. Trips by start date ascending, items by start date ascending, documents by `createdAt` descending. Tapping a trip or itinerary result routes through `AppRouter.pendingTripDetail` so the navigation flow is identical to a notification tap. Tapping a document opens QuickLook in place.

There is no on-disk index. The dataset is small enough that an in-memory scan per query is fast and the code stays simple.

## Location Actions

Itinerary items hold a free-text `locationName` and `address`. When either field is non-blank, the editor shows an "Open in Maps" row and the timeline row shows a context menu with the same actions plus per-field copy. URLs are built with `URLComponents` and opened with `UIApplication.open`. There is no MapKit dependency, no geocoding, and no location permission.

## Notification Routing

When the user taps a reminder banner, the system delivers the response to `NotificationResponseHandler`, which:

1. Parses the `userInfo` payload via `NotificationRouteParser` into a `PendingTripRoute { tripId, itemId? }`.
2. Hops to the `@MainActor` and assigns the route to `AppRouter.pendingTripDetail`.

`TripListView` observes that publisher and, on a non-nil route:

1. Resolves the trip from the repository (in case the entity was deleted between scheduling and delivery).
2. Resets the navigation path and pushes a `TripDestination { trip, focusItemId }` value.
3. Clears the pending route.

`TripDetailView` consumes `focusItemId` once after items load, opening the editor for the targeted item. A one-shot `hasConsumedFocus` flag prevents re-presentation if the user dismisses the editor and the `.task` re-fires on back-navigation.

This keeps deep linking in the navigation layer. No router coupling pushed into the detail view, no race between the route clear and the consumer.

## Testing Strategy

The test suite covers business logic, repository round-trips, and view-model behavior:

- **View models.** `TripListViewModel`, `TripDetailViewModel`, `TripEditorViewModel`, `ItineraryItemEditorViewModel`, `DocumentListViewModel`, `DocumentVaultViewModel`, `SettingsViewModel`, `SearchViewModel` (load, save, delete, validation, focus, error paths, reminder scheduling, outside-range confirmation, rename, item association, search debounce and cancellation, copy feedback state).
- **Repositories.** `CoreDataTripRepository`, `CoreDataItineraryRepository`, `CoreDataDocumentRepository` using in-memory stacks (CRUD, sort order, foreign-key errors, cascade and nullify rules).
- **Services.** `FileManagerDocumentStorageService` round-trips real files in a sandboxed temp dir, including 25 MB cap enforcement and idempotent deletes. `LocalDataManagementService` covers the full clear-all-data flow. `LocalSearchService` covers substring matching across all three datasets.
- **Domain utilities.** `ItineraryFocusResolver`, `TravelDocument` filtering, `ImageFormatDetection`, `ReminderOption`, `NotificationRouteParser`, `AppRouter`, `AppleMapsURL`, `LocationActionAvailability`.

Patterns used:

- Actor-isolated mocks (`MockTripRepository`, `MockDocumentRepository`, `MockSearchService`, etc.) for view-model tests.
- `@Sendable () -> Date` injection for deterministic "now."
- Real in-memory Core Data stacks (`CoreDataStack(inMemory: true)`) for repository tests rather than mocking Core Data itself.

## Known Limitations

- **No cloud sync.** Trips and documents are device-local. Reinstalling or switching devices loses data unless restored from an iCloud device backup.
- **No timezone awareness for reminders.** Reminder fire times are absolute offsets from the item's stored `Date`. Changing timezones between scheduling and delivery does not shift the fire moment to the destination's local time.
- **No Core Data model migration scaffolding.** The schema is at version 1. The first schema change post-ship will require adding a model version and lightweight migration setup.
- **No orphan file sweeper.** If the app is force-killed between a file copy and the metadata write, an orphan file may be left in the sandbox. In-process error paths roll back correctly.
- **Reminders persist a `reminderOffset` even if the user has denied notifications.** An inline hint surfaces in the editor, but the denied state is not flagged on the trip detail or item row.

## Roadmap

Possible directions for future versions, in no particular order:

- Per-itinerary destination timezone support for reminders
- A WidgetKit widget showing the next upcoming event
- Reservation or screenshot OCR import
- Cloud sync via CloudKit
- iPad layout pass

## Setup

**Requirements**

- Xcode 16 or newer
- iOS 17.6 or newer (simulator or device)
- macOS Sonoma or newer

**Steps**

```bash
git clone https://github.com/<your-username>/TripKite.git
cd TripKite
open TripKite.xcodeproj
```

In Xcode:

1. Select the `TripKite` scheme.
2. Choose an iPhone simulator (or a real device for notification and Apple Maps testing).
3. Press **⌘R** to run.
4. Press **⌘U** to run the test suite.

No package resolution or signing setup is required for simulator builds.

## Engineering Decisions

A few design choices worth calling out:

- **Pure-Swift domain models with a mapping boundary.** `NSManagedObject` subclasses never leak out of the persistence layer. View models and tests work with `Sendable` value types, which keeps the test suite fast and the rest of the codebase decoupled from Core Data.
- **A fresh background context per repository call.** Reads and writes never block the main thread, and each call is its own transactional boundary. Repository tests use real in-memory Core Data stacks rather than mocking Core Data itself; Core Data's behavior is too load-bearing to mock cheaply.
- **Files outside Core Data, metadata inside.** Document bytes live in the app sandbox under a UUID filename; only metadata is persisted. The two-write sequence has an explicit rollback so a failed metadata write doesn't leave orphan files on disk.
- **Protocol-based dependency injection without a framework.** The graph is built once in `TripKiteApp.init` and threaded down through view initializers. Each system capability (notifications, document storage, search, location actions) sits behind a `Sendable` protocol that mocks satisfy directly.
- **Single notification identifier scheme.** `trip-<tripId>-item-<itemId>` lets the scheduling service cancel a single reminder by item id or every reminder for a trip on deletion using a single substring match.
- **One deep-link channel for two flows.** Both notification taps and search-result taps assign to `AppRouter.pendingTripDetail`, which `TripListView` consumes once. There is no parallel router state for search.
- **UIKit isolated behind a service.** `LocationActionService` is the only seam that touches `UIApplication.open` and `UIPasteboard`. View models depend on the protocol, which keeps them testable and keeps UIKit out of the rest of the code.
- **Deferred Core Data migration scaffolding.** The schema is at version 1. Migration setup is straightforward to add when the first schema change is needed; adding it preemptively would be premature complexity.
