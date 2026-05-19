# Manual QA Checklist

A walkthrough for verifying the V1 happy paths before tagging a build. Run the XCTest suite (**⌘U**) first; this checklist covers behavior that the automated tests don't directly assert.

Notification banners do not render in the simulator unless triggered manually. Run reminder checks on a real device or use **Features → Trigger Local Notification** in the simulator.

## Trips

- Create a new trip; confirm it appears in the Upcoming section sorted by start date.
- Edit the trip's title and dates; confirm the changes propagate to the trip detail header, list row, and any associated badges.
- Delete a trip via swipe; confirm both the row and any associated documents are removed.
- Confirm the empty state appears after deleting all trips.

## Itinerary

- Add an itinerary item with start and end times; confirm it appears in the timeline grouped under the correct day.
- Add an item with no end time; confirm the row renders without a time range and the focus card treats it as a point event.
- Add an item with a start date outside the trip's range; confirm the "Outside trip dates" confirmation appears and respects Cancel / Save Anyway.
- Add an item whose start time is in the past but inside the trip; confirm it saves without confirmation.
- Delete an item via swipe; confirm the row disappears and any reminder for it is cancelled.
- Confirm the timeline empty state appears when all items are removed.
- Open the Happening Now / Up Next card and confirm it routes to the correct item editor.

## Reminders

- Add an item with a 1-minute reminder; lock the device; confirm the banner fires and tapping it opens the item's editor.
- Schedule a reminder a minute out and leave the app foregrounded; confirm a banner and sound appear.
- Change an item's reminder offset; confirm the previous reminder is cancelled and the new one is scheduled.
- Set a reminder on an item that starts in the past; confirm the item saves without a system notification being scheduled and no error is shown.
- Deny notification permission system-wide; confirm the editor shows an inline hint and the item still saves.

## Documents

- Attach a PDF via Files; verify the row shows file name, size, and type, and that tap opens QuickLook.
- Attach a screenshot via Photos; verify the row title starts with `Screenshot-` or `Photo-` and the file type is detected correctly (PNG / JPG / HEIC).
- Rename a document with and without a matching extension suffix; verify trailing `.png` / `.pdf` is stripped from the display name and the underlying file path is unchanged.
- Assign a document to an itinerary item via the context menu; confirm a paperclip icon appears on the item's timeline row.
- Open that item's editor and confirm the associated document is listed in the Documents section.
- Reassign a document to a different item; confirm the paperclip moves with it.
- Reassign a document back to trip-level; confirm the paperclip disappears from the previous item.
- Delete a document via swipe or context menu; confirm it disappears from every section that referenced it.
- Attempt to import a file larger than 25 MB; confirm a "too large" alert appears and nothing is copied to the sandbox.

## Cleanup

- Delete a trip with attached documents and a scheduled reminder; confirm:
  - Trip row disappears
  - Itinerary items are removed
  - Document records are removed
  - Files in `Documents/Attachments/` are removed
  - Scheduled reminders for the trip are cancelled

## App lifecycle

- Cold-launch via a notification tap; confirm the app opens directly to the trip detail with the correct item editor presented.
- Background the app and re-tap a notification for a different item in the same trip; confirm the navigation stack resets and the new item's editor is presented.
- Force-quit the app mid-import (where possible) and re-open; confirm the trip list still loads and no spurious orphan rows appear.
