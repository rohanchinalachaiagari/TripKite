# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

# TripKite

TripKite is an offline-first iOS travel companion app built with SwiftUI. Users can create trips, add itinerary items, attach travel documents, schedule reminders, and view their trip timeline without requiring network access.

(The on-disk Xcode project, scheme, and Swift module are still named `TripKit` for historical reasons. The product ships as **TripKite**.)

The goal of this project is to demonstrate production-style iOS engineering: clean architecture, local persistence, dependency injection, testability, offline-first design, and thoughtful mobile-specific behavior.

---

## Product Vision

TripKite helps users keep all important trip information in one place:

- Upcoming and past trips
- Flights, hotels, activities, restaurants, and transportation
- Confirmation numbers and notes
- Local document attachments such as PDFs, tickets, screenshots, and reservations
- Local reminders before important itinerary events
- A chronological trip timeline that works offline

This is intentionally not a full travel booking app. The focus is on itinerary organization, offline reliability, and strong iOS architecture.

---

## MVP Scope

Build the smallest version that still feels polished and technically meaningful.

### Must Have

- Create, edit, and delete trips
- Add itinerary items to a trip
- Sort itinerary items chronologically
- Categorize itinerary items by type
- Store all data locally
- View upcoming and past trips
- Attach local documents to a trip or itinerary item
- Schedule local reminders for itinerary items
- Unit tests for the core business logic

### Nice to Have

- Search trips and itinerary items
- Filter by itinerary type
- Basic app settings
- Reusable design system components
- Widget showing next upcoming trip or event
- Import reservation screenshots in a later version

### Out of Scope for V1

- User accounts
- Firebase
- Cloud sync
- Payment flows
- Social features
- Real-time collaboration
- Flight status APIs
- AI itinerary generation

Do not add out-of-scope features unless explicitly requested.

---

## Technical Goals

Prioritize these engineering qualities:

1. Offline-first behavior
2. Clear separation of concerns
3. Testable ViewModels and services
4. Simple, readable Swift code
5. Minimal dependencies
6. Predictable state management
7. Strong error handling
8. Clean, interview-ready architecture

This app should feel like a small production app, not a tutorial project.

---

## Tech Stack

Use the following unless explicitly changed:

- Swift
- SwiftUI
- Core Data for local persistence
- UserNotifications for local reminders
- FileManager for document storage
- PhotosUI / DocumentPicker where appropriate
- XCTest for unit tests

Avoid adding third-party packages unless there is a strong reason. Prefer Apple-native frameworks.

---

## Architecture

TripKite should use MVVM with a repository and service layer.

Preferred dependency direction:

```text
SwiftUI View
    ↓
ViewModel
    ↓
Use Case / Service / Repository Protocol
    ↓
Concrete Repository / Local Store / Apple Framework
```

Views should not directly access Core Data, FileManager, UserNotifications, or other system APIs.

### Main Architectural Rules

- SwiftUI Views should be lightweight and declarative.
- ViewModels own presentation state and user actions.
- ViewModels should depend on protocols, not concrete implementations.
- Repositories handle persistence.
- Services handle system capabilities such as notifications and document storage.
- Business rules should live outside Views.
- Avoid putting complex logic inside SwiftUI body blocks.
- Prefer dependency injection over singletons.
- Use mock implementations in tests.

---

## Suggested Folder Structure

```text
TripKit/
  App/
    TripKiteApp.swift
    AppRouter.swift

  Core/
    Models/
      Trip.swift
      ItineraryItem.swift
      TravelDocument.swift
      ItineraryType.swift
      TripStatus.swift

    Persistence/
      CoreDataStack.swift
      CoreDataTripRepository.swift

    Repositories/
      TripRepository.swift
      ItineraryRepository.swift
      DocumentRepository.swift

    Services/
      NotificationSchedulingService.swift
      DocumentStorageService.swift
      DateProvider.swift

    DesignSystem/
      TKButton.swift
      TKCard.swift
      TKEmptyStateView.swift
      TKErrorView.swift
      TKLoadingView.swift

    Utilities/
      DateFormatting.swift
      Validation.swift

  Features/
    Trips/
      TripListView.swift
      TripListViewModel.swift
      TripDetailView.swift
      TripDetailViewModel.swift
      TripEditorView.swift
      TripEditorViewModel.swift

    Itinerary/
      ItineraryTimelineView.swift
      ItineraryItemRow.swift
      ItineraryItemEditorView.swift
      ItineraryItemEditorViewModel.swift

    Documents/
      DocumentListView.swift
      DocumentPickerView.swift
      DocumentPreviewView.swift
      DocumentViewModel.swift

    Reminders/
      ReminderSettingsView.swift
      ReminderViewModel.swift

  Tests/
    TripKitTests/
      TripListViewModelTests.swift
      TripDetailViewModelTests.swift
      ItinerarySortingTests.swift
      ReminderSchedulingTests.swift
      MockTripRepository.swift
      MockNotificationSchedulingService.swift
```

Keep files focused. If a file grows too large, split it by responsibility.

---

## Core Domain Models

Use models that are simple, explicit, and easy to test.

### Trip

A trip represents a user-created travel plan.

Suggested properties:

- id
- title
- destination
- startDate
- endDate
- notes
- createdAt
- updatedAt

Derived behavior:

- upcoming if endDate is today or later
- past if endDate is before today
- invalid if endDate is earlier than startDate

### ItineraryItem

An itinerary item represents something scheduled during a trip.

Suggested properties:

- id
- tripId
- title
- type
- startDate
- endDate
- locationName
- address
- confirmationNumber
- notes
- reminderDate
- createdAt
- updatedAt

Supported itinerary types:

- flight
- hotel
- activity
- restaurant
- transportation
- note
- other

### TravelDocument

A document represents a locally stored file related to a trip or itinerary item.

Suggested properties:

- id
- tripId
- itineraryItemId optional
- fileName
- localFilePath
- fileType
- createdAt

Do not store large binary files directly in Core Data. Store files in the app sandbox and persist metadata only.

---

## State Management

Prefer explicit view state.

Example:

```swift
enum ViewState<Value> {
    case idle
    case loading
    case loaded(Value)
    case empty
    case error(Error)
}
```

Use this pattern when a screen has meaningful loading, empty, success, and error states.

For simpler screens, plain `@Published` or `@Observable` state is acceptable.

---

## SwiftUI Guidelines

- Keep Views focused on layout.
- Move formatting and business logic out of Views.
- Avoid deeply nested view bodies.
- Extract reusable components when a view becomes hard to read.
- Use private computed properties for smaller view sections.
- Prefer `NavigationStack` for navigation.
- Prefer `.task` for async loading when appropriate.
- Avoid triggering important side effects repeatedly from `onAppear`.
- Always handle empty states.
- Always handle error states.

Bad:

```swift
Button("Save") {
    // validation, persistence, notification scheduling, and navigation all here
}
```

Better:

```swift
Button("Save") {
    Task { await viewModel.saveTapped() }
}
```

---

## ViewModel Guidelines

- ViewModels should be responsible for presentation state and user actions.
- Use `@MainActor` for ViewModels that update UI state.
- Do not reference SwiftUI Views from ViewModels.
- Inject dependencies through initializers.
- Avoid direct calls to concrete persistence or system APIs.
- Expose simple state for the View to render.

Example:

```swift
@MainActor
final class TripListViewModel: ObservableObject {
    @Published private(set) var trips: [Trip] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let tripRepository: TripRepository
    private let dateProvider: DateProvider

    init(
        tripRepository: TripRepository,
        dateProvider: DateProvider = SystemDateProvider()
    ) {
        self.tripRepository = tripRepository
        self.dateProvider = dateProvider
    }
}
```

---

## Repository Guidelines

Repositories abstract persistence details from the rest of the app.

Define protocols first:

```swift
protocol TripRepository {
    func fetchTrips() async throws -> [Trip]
    func createTrip(_ trip: Trip) async throws
    func updateTrip(_ trip: Trip) async throws
    func deleteTrip(id: UUID) async throws
}
```

Concrete implementations can use Core Data, but ViewModels should not know that.

This allows tests to use mock repositories.

---

## Notification Guidelines

Use a dedicated notification service.

Responsibilities:

- Request notification permission
- Schedule itinerary reminders
- Cancel reminders when an item is deleted
- Update reminders when an item changes

Do not call `UNUserNotificationCenter` directly from Views or ViewModels.

Preferred protocol:

```swift
protocol NotificationSchedulingService {
    func requestAuthorization() async throws -> Bool
    func scheduleReminder(for item: ItineraryItem) async throws
    func cancelReminder(for itemId: UUID) async
}
```

Reminder edge cases to handle:

- Reminder date is in the past
- User denies notification permission
- Itinerary item is deleted
- Itinerary item time changes

---

## Document Storage Guidelines

Use a dedicated document storage service.

Responsibilities:

- Copy selected files into the app sandbox
- Generate stable local file paths
- Delete files when a document is removed
- Return metadata for persistence

Do not store large file blobs in Core Data.

Preferred protocol:

```swift
protocol DocumentStorageService {
    func saveDocument(from sourceURL: URL, fileName: String) async throws -> TravelDocument
    func deleteDocument(_ document: TravelDocument) async throws
    func localURL(for document: TravelDocument) throws -> URL
}
```

---

## Error Handling

Use meaningful error types where practical.

Example:

```swift
enum TripValidationError: LocalizedError {
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
```

Avoid plain string errors for core business logic.

---

## Validation Rules

Implement validation outside Views.

Trip validation:

- Trip title cannot be empty.
- Destination cannot be empty.
- End date cannot be before start date.

Itinerary validation:

- Title cannot be empty.
- Start date should be within the parent trip date range when possible.
- End date cannot be before start date.
- Reminder date cannot be after the itinerary start date.
- Reminder date should not be scheduled in the past.

---

## Testing Standards

Write tests for behavior, not implementation details.

Prioritize tests for:

- Trip creation validation
- Trip editing validation
- Upcoming trip filtering
- Past trip filtering
- Itinerary chronological sorting
- Itinerary grouping by date
- Reminder scheduling rules
- Reminder cancellation rules
- Document metadata creation
- Repository success and failure states

Use mock repositories and mock services.

Example test names:

```swift
func testCreateTrip_WhenEndDateIsBeforeStartDate_ShowsValidationError()
func testFetchTrips_SortsUpcomingTripsByStartDate()
func testDeleteItineraryItem_CancelsScheduledReminder()
func testScheduleReminder_WhenReminderDateIsInPast_ReturnsError()
```

---

## Code Style

- Prefer clarity over cleverness.
- Use descriptive names.
- Avoid force unwraps.
- Avoid force casts.
- Avoid global mutable state.
- Avoid unnecessary singletons.
- Keep functions small and focused.
- Use access control intentionally.
- Prefer `private` for implementation details.
- Prefer `let` over `var` when possible.
- Use enums for finite state.
- Use protocols for dependencies that need to be mocked.

---

## Dependency Rules

Before adding a new dependency, consider whether Apple-native frameworks are enough.

Do not add third-party packages for:

- Basic networking
- Basic persistence
- Basic date formatting
- Simple UI components
- Basic dependency injection

Ask before adding any third-party package.

---

## Build and Run

Use Xcode as the primary development environment.

When creating the Xcode project, use:

- Interface: SwiftUI
- Language: Swift
- Testing System: XCTest
- Storage: Core Data

Do not enable CloudKit for V1.

Common tasks:

```text
Open project:
- Open TripKit.xcodeproj or TripKit.xcworkspace in Xcode

Run app:
- Select an iPhone simulator
- Press Cmd + R

Run tests:
- Press Cmd + U
```

If command-line build support is added later, document the exact `xcodebuild` commands here.

---

## Development Workflow for Claude

When implementing a feature:

1. Identify the feature area.
2. Check existing models, repositories, services, and ViewModels.
3. Add or update protocols before concrete implementations.
4. Keep Views simple.
5. Add tests for meaningful business logic.
6. Avoid broad rewrites unless necessary.
7. Preserve existing folder structure.
8. Explain major architectural decisions in comments only when the code is not self-evident.

When modifying code:

- Prefer small, targeted changes.
- Do not introduce unrelated refactors.
- Do not silently change architecture patterns.
- Do not remove tests unless replacing them with better coverage.
- Do not add networking, Firebase, or cloud sync unless explicitly requested.

---

## Interview Talking Points to Preserve

This project should support these technical deep dives:

### Offline-First Design

The app stores all trip data locally so users can access their itinerary without internet access. This is useful for travel scenarios where connectivity may be unreliable.

### Repository Pattern

ViewModels depend on repository protocols instead of concrete persistence implementations. This keeps the app testable and makes future cloud sync easier.

### Local Persistence

Core Data stores structured trip and itinerary metadata. Files are stored separately in the app sandbox, while only metadata is persisted.

### Notification Scheduling

Reminder logic is isolated in a notification service so the app can schedule, update, and cancel local notifications without coupling this behavior to UI code.

### Testability

The app uses protocols and mock services so ViewModels can be unit tested without Core Data, FileManager, or UserNotifications.

### Future Sync Readiness

The repository layer makes it possible to add a remote data source later without rewriting the UI layer.

---

## README Expectations

The README should eventually include:

- Project overview
- Screenshots or demo GIF
- Architecture diagram
- Tech stack
- Feature list
- Setup instructions
- Testing instructions
- Key technical decisions
- Future roadmap

Keep the README professional and recruiter/interviewer-friendly.

---

## Design Direction

Use a clean, modern travel-app aesthetic.

Preferred feel:

- Simple card-based UI
- Clear hierarchy
- Large readable trip titles
- Subtle icons for itinerary types
- Timeline-style itinerary view
- Empty states that explain what to do next
- Calm, polished interface

Avoid spending too much time on visual perfection before the architecture and core flows work.

---

## Suggested MVP Milestones

### Milestone 1: App Foundation

- Create project
- Add folder structure
- Add core models
- Add mock data
- Build trip list and trip detail UI

### Milestone 2: Local Persistence

- Add Core Data
- Create trip repository protocol
- Create Core Data repository implementation
- Add create/edit/delete trip flow

### Milestone 3: Itinerary Timeline

- Add itinerary item model
- Add itinerary repository
- Add itinerary editor
- Sort items chronologically
- Group items by date

### Milestone 4: Reminders

- Add notification service protocol
- Request notification permission
- Schedule local reminders
- Cancel reminders when itinerary items are deleted

### Milestone 5: Documents

- Add document picker
- Copy files into app sandbox
- Store document metadata
- Display attached documents
- Delete attached documents safely

### Milestone 6: Testing and Polish

- Add unit tests
- Add empty states
- Add error states
- Improve design system
- Add README and screenshots

---

## Non-Negotiables

- Do not call Core Data APIs directly from SwiftUI Views.
- Do not put business logic in SwiftUI body blocks.
- Do not add Firebase or a backend in V1.
- Do not introduce third-party dependencies without approval.
- Do not skip error and empty states.
- Do not use force unwraps unless there is a clearly justified reason.
- Do not build features outside the MVP before core flows are complete.

---

## Preferred Implementation Order

1. Models
2. Mock data
3. Static SwiftUI screens
4. ViewModels
5. Repository protocols
6. Core Data implementations
7. Create/edit/delete flows
8. Notification service
9. Document storage service
10. Tests
11. README polish

This order keeps the project understandable and prevents premature complexity.

---

## Final Goal

The finished project should be something that can be explained in interviews as:

> TripKite is an offline-first SwiftUI travel companion app that lets users manage trips, itinerary items, documents, and reminders locally. I built it with MVVM, protocol-based repositories, Core Data persistence, local notification scheduling, document storage, and unit-testable architecture. The main engineering focus was designing a small app with production-style separation of concerns and future sync readiness.

