# Navee — Codebase Guide for Beginners

This document explains every file in the Navee project in plain language.
No coding experience needed to read it.

---

## What is Navee?

Navee is an iPhone app for trekking and hiking. It lets you:
1. **Mark points** on a map while you walk (like dropping a pin)
2. **Edit those points** — rename them, change their icon, add a photo
3. **Navigate back** to a saved point using a compass screen

---x

## Before Reading the Files — Key Concepts

These words appear everywhere in the code. Learn them once and the rest will make sense.

---

### `struct` — A Blueprint for Data

A **struct** is like a form template. It defines what information something has.

```swift
struct Location { ... }
```

Think of it like a form for a saved point. The form has fields: name, coordinates, altitude, icon, photo, etc. Every saved point is one filled-out copy of that form.

---

### `class` — A Blueprint That Can Be Shared and Watched

A **class** is similar to a struct, but it can be observed for changes and shared across many parts of the app at the same time.

```swift
class LocationTracker { ... }
```

Think of it like a live dashboard on the wall. Many people can look at it and they all see the same up-to-date information.

---

### `var` and `let`

- `let` = a box whose contents **cannot change** once set (like a printed label)
- `var` = a box whose contents **can change** (like a whiteboard you can erase)

```swift
let id = UUID()     // This ID is permanent — never changes
var name = "Point"  // The user can rename this
```

---

### `@State` — A Memory Box that Refreshes the Screen

When a value inside a View changes, SwiftUI needs to know so it can redraw the screen. `@State` is how you tell it to watch that value.

```swift
@State private var showCamera = false
```

Think of it like a light switch connected to a camera. When you flip `showCamera` to `true`, the camera screen appears automatically. You didn't have to manually tell the screen to open — `@State` handles that connection.

**Rule:** Only the View that owns `@State` can change it directly.

---

### `@Binding` — A Shared Light Switch

Sometimes a child view needs to control a value that belongs to its parent. `@Binding` passes a **live link** to that value, not a copy.

```swift
@Binding var photoData: Data?
```

Imagine two light switches in a house wired to the same bulb. One is in the parent room (`@State`), one is in the child room (`@Binding`). Flipping either switch changes the same bulb. The child doesn't own the bulb — it just has a remote control for it.

**How to pass a `@Binding`:** Use a `$` prefix.
```swift
PointPhotoPickerView(photoData: $draft.photoData)
//                               ^ the $ means "pass a live link, not a copy"
```

---

### `@Published` — Broadcasting Changes

Used inside a `class`. Any variable marked `@Published` will automatically notify the whole app when its value changes.

```swift
@Published var userLocation: CLLocation?
```

Think of a news ticker. Whenever `userLocation` gets a new GPS position, every part of the app that's "subscribed" will see the update automatically.

---

### `@StateObject` — Creating and Watching a Class

When a View wants to create and own a `class` object, it uses `@StateObject`.

```swift
@StateObject private var tracker = LocationTracker()
```

The View creates the `LocationTracker` once and keeps watching it. If the tracker broadcasts changes (via `@Published`), the View redraws itself.

---

### `@Environment(\.dismiss)` — Closing the Current Screen

This is a built-in SwiftUI tool that gives you a "close me" function.

```swift
@Environment(\.dismiss) private var dismiss
```

When you call `dismiss()`, the current screen closes and you go back to the previous one. Used for closing the camera picker after taking a photo.

---

### `View` — A Screen or Part of a Screen

Everything visible on screen is a `View`. Views can be tiny (a single button) or large (an entire screen). Big views are made by combining small ones.

```swift
struct FootstepMarker: View { ... }  // tiny blue dot on the map
struct MainView: View { ... }        // the entire main screen
```

---

### `body` — What the View Actually Shows

Every View has one required thing: a `body`. This is where you describe what appears on screen.

```swift
var body: some View {
    Text("Hello")
}
```

---

### `Optional` — A Value That Might Not Exist

A type followed by `?` means the value might be empty (called `nil`).

```swift
var photoData: Data?      // might have a photo, might not
var userLocation: CLLocation?  // might have GPS, might not yet
```

You check if it exists using `if let`:
```swift
if let data = photoData {
    // only runs if photoData actually has something
}
```

---

### `enum` — A List of Choices

An `enum` is like a multiple-choice list where you can only pick one option at a time.

```swift
enum ArrivalKind {
    case checkpoint
    case final
}
```

This means something can either be a `checkpoint` arrival or a `final` arrival — nothing else.

---

### `extension` — Adding Features to Existing Types

You can add new functions to types you didn't write yourself.

```swift
extension Date {
    func relativeFormatted() -> String { ... }
}
```

This adds a `relativeFormatted()` function to Swift's built-in `Date` type. Now every date in the app can call it.

---

### `import` — Borrowing Apple's Toolboxes

Before using Apple's built-in tools, you have to import the right toolbox.

```swift
import SwiftUI      // everything for building screens
import CoreLocation // GPS and location tools
import PhotosUI     // photo library picker
```

---

## File-by-File Explanation

---

## App Entry Point

### `Navee/App/Navee.swift`

**What it does:** This is the very first file that runs when the app opens. Think of it as the "on" switch. It creates one window and puts `MainView` inside it.

```swift
@main                     // "start here"
struct Navee: App {
    var body: some Scene {
        WindowGroup {
            MainView()    // show this as the first screen
        }
    }
}
```

`@main` tells iOS: "this is where the app begins."
`WindowGroup` means "make one window on the screen."

---

### `Navee/ContentView.swift`

**What it does:** A thin wrapper. It exists mostly because Xcode creates it by default. It immediately shows `MainView`.

```swift
struct ContentView: View {
    var body: some View {
        MainView()   // just pass through to the real main screen
    }
}
```

---

## Models (Data)

### `Navee/Model/LocationModel.swift`

**What it does:** Defines what a **saved point** looks like. Every pin the user drops on the map is one `Location`.

```swift
struct Location: Identifiable, Hashable {
    let id: UUID          // a unique ID — like a serial number
    var name: String      // the point's name, e.g. "Camp 1"
    var coordinate: CLLocationCoordinate2D  // GPS position (latitude + longitude)
    var timestamp: Date   // when the point was saved
    var altitude: Double  // height above sea level in meters
    var emoji: String     // the icon name (e.g. "tent.fill", "flag.fill")
    var notes: String     // optional text notes
    var photoData: Data?  // optional photo — nil if no photo was taken
}
```

**`Identifiable`** means every Location has a unique ID. SwiftUI uses this to track items in lists.

**`Hashable`** means the app can quickly look up a Location in a set or dictionary.

**`UUID()`** generates a random unique ID automatically (like a fingerprint for each point).

**`Data?`** — raw bytes of an image. When you take or pick a photo, it gets converted into bytes (`Data`) and stored here.

---

### `Navee/Model/NavState.swift`

**What it does:** Tracks the math behind navigation — how far away the destination is, which direction to face, and whether you've arrived.

```swift
struct NavState {
    var userHeading: Double  // which direction the user is facing (0–360°)
    var bearing: Double      // which direction the destination is (0–360°)
    var distance: Double     // how many meters away the destination is
    var hasValidHeading: Bool // false until the compass gives a real reading

    var hasArrived: Bool {    // true when closer than 10 meters
        distance > 0 && distance <= Nav.arrivalRadius
    }

    var isOnTrack: Bool {     // true when facing roughly the right direction
        ...
    }
}
```

**Constants in `Nav`:**
- `arrivalRadius = 10` — you've "arrived" if within 10 meters
- `onTrackTolerance = 30` — you're "on track" if facing within 30° of the right direction

---

### `Navee/Model/DummyLocations.swift`

**What it does:** Holds a fake location used for testing in Xcode Previews. Without real GPS data, previews would show nothing useful.

```swift
static let demoPin = Location(
    name: "Camping Area",
    coordinate: ...,
    altitude: 39,
    emoji: "tent.fill",
    notes: "Best sunrise spot"
)
```

`static` means you access it as `DummyLocations.demoPin` — you don't need to create a `DummyLocations` object first.

---

## Utilities (Helper Code)

### `Navee/Utilities/LocationAndDistance.swift`

**What it does:** Adds distance-calculation functions to the `Location` struct.

```swift
extension Location {
    func distance(from userLocation: CLLocation?) -> Double? { ... }
    func formattedDistance(from userLocation: CLLocation?, ...) -> String { ... }
}
```

`distance(from:)` calculates how many meters the user is from this point.

`formattedDistance(from:)` turns that number into a readable string:
- If under 1000 m → `"125 m"`
- If over 1000 m → `"1.2 km"`

---

### `Navee/Utilities/DateAndFormatting.swift`

**What it does:** Adds a friendly date-formatting function to Swift's built-in `Date` type.

```swift
extension Date {
    func relativeFormatted() -> String { ... }
}
```

Instead of showing `"2026-05-07 11:49:00"`, it shows:
- `"Today, 11:49"` — if saved today
- `"Yesterday, 09:00"` — if saved yesterday
- `"7 May 2026, 11:49"` — anything older

---

### `Navee/Utilities/CLLocationCoordinate2DAndNavigation.swift`

**What it does:** Adds navigation math to GPS coordinates.

```swift
extension CLLocationCoordinate2D {
    func bearing(to destination: ...) -> Double { ... }
    func distance(to destination: ...) -> Double { ... }
}
```

`bearing(to:)` calculates the compass direction from point A to point B (e.g., "the destination is 127° — roughly south-east").

`distance(to:)` calculates the straight-line distance in meters between two GPS coordinates.

The math inside uses trigonometry (sin, cos, atan2) — standard formulas for working with a sphere (the Earth).

---

### `Navee/Utilities/PinIconHelper.swift`

**What it does:** A lookup table that maps icon names to their colours.

```swift
enum PinIconHelper {
    static let allIcons: [String] = ["mappin", "tent.fill", ...]

    static func colors(for emoji: String) -> (top: Color, bottom: Color) { ... }
    static func topColor(for emoji: String) -> Color { ... }
    static func iconName(for emoji: String) -> String { ... }
}
```

Every icon has a matching gradient (a top colour and a bottom colour). `colors(for:)` returns both. `topColor(for:)` returns just the top one (used in simpler places like list rows). This keeps all colour decisions in one place so you never have to repeat them.

---

### `Navee/Utilities/HapticEngine.swift`

**What it does:** Controls the iPhone's vibration motor (called "haptic feedback") during navigation.

```swift
enum HapticEngine {
    static func wrongWay()   { ... }  // warning buzz when heading wrong direction
    static func backOnTrack() { ... } // soft tap when back on course
    static func arrived()    { ... }  // success buzz when reaching the destination
}
```

These use Apple's `UINotificationFeedbackGenerator` and `UIImpactFeedbackGenerator` — built-in tools for different vibration patterns.

---

### `Navee/Utilities/ArrayAndSafeSubscript.swift`

**What it does:** Makes it safe to access items in a list by index, even if the index is out of range.

```swift
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

Normally, accessing `myArray[5]` when the array only has 3 items crashes the app. `myArray[safe: 5]` returns `nil` instead of crashing. Used in the navigation code to safely get the current waypoint.

---

### `Navee/Utilities/MapConfig.swift`

**What it does:** Stores default values for the map (starting position and zoom level).

```swift
enum MapConfig {
    static let defaultCenter = CLLocationCoordinate2D(...)
    static let defaultSpan: Double = 500
}
```

`defaultSpan` is how many meters wide the map view is when it first opens.

---

## App Logic

### `Navee/App/LocationTracker.swift`

**What it does:** The GPS and compass brain. It constantly reads the user's position and direction from the phone's sensors and broadcasts updates.

```swift
class LocationTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var userLocation: CLLocation?    // current GPS position
    @Published var heading: Double = 0          // current compass direction
    @Published var authorizationStatus: ...     // has the user allowed GPS?
```

**`ObservableObject`** — means SwiftUI Views can subscribe to this class. When any `@Published` value changes, all subscribed Views redraw.

**`CLLocationManagerDelegate`** — iOS calls functions on this class when new GPS or compass data arrives.

**`startTracking()`** — requests permission if needed, then starts the GPS and compass.
**`stopTracking()`** — pauses sensors (saves battery when not navigating).
**`currentLocation()`** — returns the latest known position.

**Filter values** — GPS updates only if the new position is at least 1 metre different and accurate within 20 metres. This prevents jitter from bad GPS signals and reduces battery drain.

---

## Views — The Screens

### `Navee/View/MainView.swift`

**What it does:** The main screen. Shows the map, handles pins, and coordinates all the sheets (pop-up panels).

**Key state variables:**
```swift
@State private var locations: [Location]       // all the saved points
@State private var isTracking: Bool            // has the user pressed "Start Trekking"?
@State private var sheetContent: MarkSheetContent?  // which panel is currently open
@State private var compassDestinationIndex: Int?    // which point we're navigating to
```

**What appears on screen:**
1. A full-screen `Map` with pins and a walking-person marker
2. `StartOverlay` — the welcome screen shown before tracking starts
3. `TrackingToolbar` — the "Add Mark" and "Saved Points" buttons shown during tracking
4. A **sheet** (bottom panel) for showing point details, lists, and editing
5. A **fullScreenCover** for the compass navigation screen

**`addMark()`** — reads the current GPS position and creates a new `Location`, adding it to the `locations` array.

**`safeAreaInset`** — pushes the map upward when the detail sheet is open so the selected pin isn't hidden behind the panel.

**`RoundedCorner`** — a custom shape helper that rounds only specific corners of a rectangle (used for UI styling).

---

### `Navee/View/CompassNavigationView.swift`

**What it does:** The full-screen navigation mode. Shows a compass pointing toward the destination and tracks progress through multiple waypoints.

**How breadcrumbs work:**
```swift
private var breadcrumbs: [Location] { ... }
```
The user picks a destination point. All points *between the user's starting point and that destination* become intermediate checkpoints. The user walks through them in reverse order (from the furthest back to the nearest).

**Key logic:**
- `updateNav(from:)` — recalculates bearing and distance whenever GPS updates
- `checkArrival()` — when within 10m of a checkpoint, advances to the next one with an animated flash
- `triggerFlash(_:)` — shows the "Checkpoint" overlay briefly, then hides it

**`ArrivalOverlay`** — the "You've Arrived" card shown when reaching the final destination. Has a green checkmark and a "Done" button.

---

### `Navee/View/ModifyPin.swift`

**What it does:** The "Edit Point" screen. Shown as a sheet when the user taps Edit on a saved point. Lets them rename it, change the icon, add/remove a photo, and see saved info.

```swift
struct ModifyPin: View {
    @Binding var location: Location   // live link to the real saved point
    @State private var draft: Location  // a temporary copy to edit
```

**The `draft` pattern:** Instead of editing the real `location` directly, a copy called `draft` is made. All edits happen on `draft`. Only when the user taps the ✓ checkmark does `location = draft` save the changes. If the user goes back without saving, the original is untouched.

**Sections in the List:**
1. `nameSection` — text field for the point name with a 20-character counter
2. `IconPickerSection` — horizontal scrollable row of icon choices
3. `photoSection` — the photo picker area (described below)
4. `infoSection` — read-only rows: Distance, Altitude, Coordinates, Saved date
5. `deleteSection` — red "Delete Location" button with a confirmation alert

**`IconPickerSection`** — handles the fade masks on the left/right edges of the horizontal icon scroll. The fade appears when there are more icons to scroll to. Uses `onScrollGeometryChange` to track the scroll position.

---

### `Navee/View/Components/PointPhotoPickerView.swift`

**What it does:** The photo area inside the Edit Point screen. Lets the user take a photo with the camera or pick one from their library. The selected photo is saved to the point.

```swift
struct PointPhotoPickerView: View {
    @Binding var photoData: Data?    // lives in the parent (ModifyPin's draft)
```

**The two-state display (`photoContent`):**
- If `photoData` has a photo → shows the image with an `×` remove button
- If `photoData` is nil → shows a dark box with a camera icon

**Tap to open options:**
```swift
.onTapGesture { showOptions = true }
.confirmationDialog(...) {
    Button("Take Photo")          { showCamera = true }
    Button("Choose from Library") { showPhotosPicker = true }
    Button("Remove Photo", ...)   { photoData = nil }
}
```
`confirmationDialog` is the action sheet (the menu that slides up from the bottom with options).

**Camera (`CameraPickerView`):**
SwiftUI doesn't have a built-in camera, so we wrap Apple's older `UIImagePickerController` using `UIViewControllerRepresentable`. This is a bridge between SwiftUI and the older UIKit world.

```swift
private struct CameraPickerView: UIViewControllerRepresentable {
```

The `Coordinator` class handles what happens when the user takes a photo:
```swift
func imagePickerController(... didFinishPickingMediaWithInfo ...) {
    parent.photoData = image.jpegData(compressionQuality: 0.8)
    parent.dismiss()
}
```
`jpegData(compressionQuality: 0.8)` converts the `UIImage` into bytes (`Data`) at 80% quality — good quality, smaller file.

**Photo Library (`PhotosPicker`):**
This is a modern SwiftUI built-in (iOS 16+). It stores the selection in `pickerItem`. When `pickerItem` changes, the `onChange` block loads the actual image bytes:
```swift
.onChange(of: pickerItem) { _, item in
    Task {
        if let data = try? await item?.loadTransferable(type: Data.self) {
            photoData = data
        }
    }
}
```
`Task` runs code asynchronously (in the background) so the UI doesn't freeze while loading the image. `await` means "wait here until this finishes, but don't block the screen."

---

### `Navee/View/Components/UnifiedMarkSheet.swift`

**What it does:** The single bottom sheet that can show three different things depending on what the user tapped. Think of it as one sliding panel with three "modes."

**The three modes (`MarkSheetContent`):**
```swift
enum MarkSheetContent {
    case list           // list of all saved points
    case detail(Location)  // mini card for one selected point
    case edit(Location.ID) // the full Edit Point form
}
```

**Two sheet heights:**
```swift
struct SmallDetent: CustomPresentationDetent {
    // 240 points tall — used for detail cards without a photo
    static func height(...) -> CGFloat? { 240 }
}
struct PhotoDetailDetent: CustomPresentationDetent {
    // 370 points tall — used when the point has a photo
    static func height(...) -> CGFloat? { 370 }
}
```
A "detent" is a fixed height the sheet snaps to. The sheet is taller when a photo needs to be shown.

**`detailDetent(for:)`** — picks the right height:
```swift
private func detailDetent(for location: Location) -> PresentationDetent {
    let live = locations.first(where: { $0.id == location.id }) ?? location
    return live.photoData != nil ? .custom(PhotoDetailDetent.self) : .custom(SmallDetent.self)
}
```
Looks up the current version of the location (to catch any recent edits), then checks if it has a photo.

**Key animation logic:**
- `isDismissing` — prevents the sheet from snapping upward before sliding down when closing
- `isGoingToEdit` — prevents the sheet from switching to "list" mode while animating from detail → edit
- `isExpandingForEdit` — keeps both small detents available during the detail→edit expansion animation (so iOS knows the starting height)

---

### `Navee/View/Components/BottomPinDetailView.swift`

**What it does:** The compact card shown when the user taps a pin on the map. Shows basic info and two action buttons.

**Photo display (new feature):**
```swift
if let data = location.photoData, let image = UIImage(data: data) {
    Image(uiImage: image)
        .resizable()
        .scaledToFill()
        .frame(maxWidth: .infinity)
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 12))
}
```
`if let` — only shows this block if the point actually has a photo saved. If there's no photo, this block is completely skipped and the layout looks exactly like before.

`UIImage(data: data)` — converts raw bytes back into a displayable image.

`scaledToFill` + `clipShape` — fills the rectangle with the photo and cuts off any overflow around the rounded corners.

**Buttons:**
- **Navigate (blue)** — closes the sheet and opens the compass navigation screen
- **Edit (glass)** — opens the Edit Point form (uses iOS 26's Liquid Glass effect via `.glassEffect`)

---

### `Navee/View/Components/SavedMarkRow.swift`

**What it does:** One row in the "Saved Points" list. Shows the icon, name, distance, and altitude for a point. Tapping it selects it on the map.

```swift
.onTapGesture { onSelect() }
```
`onSelect` is a function passed in from the parent. When tapped, the parent decides what to do (in this case, it moves the map to that pin and opens the detail card).

---

### `Navee/View/Components/StartOverlay.swift`

**What it does:** The welcome screen shown before the user starts tracking. Has a background image, an island illustration, a tagline, and a "Start Trekking" button.

```swift
Button(action: onStart) { ... }
```
`onStart` is a function passed in. When tapped, it tells the parent (`MainView`) to set `isTracking = true`, which hides this overlay and shows the tracking toolbar.

---

### `Navee/View/Components/TrackingToolbar.swift`

**What it does:** The toolbar at the bottom of the map screen during tracking. Has two buttons:

1. **Saved Points button (orange circle)** — opens the list sheet. Shows a green badge with the pin count.
2. **Add Mark button (blue capsule)** — saves the current GPS location as a new point.

`PinCountBadge` — the small green circle with a number. Caps at 99 (shows "99" even if there are 100 points, to prevent overflow).

---

### `Navee/View/Components/DynamicTearDropPin.swift`

**What it does:** The teardrop-shaped pin that appears on the map. Gets bigger and shows a white border when selected (like Apple Maps pins).

```swift
private var circleSize: CGFloat { isSelected ? 48 : 36 }
```
When `isSelected` is true, the pin is 48 points wide. When not selected, 36 points.

**`PinTail` shape:** Draws the triangular tail at the bottom of the pin using a custom `Path` (three points forming a triangle).

**`animation(..., value: isSelected)`** — animates the size change with a spring effect whenever `isSelected` flips.

---

### `Navee/View/Components/FootstepMarker.swift`

**What it does:** The blue walking-person dot that shows the user's current GPS position on the map. Three circles stacked on top of each other: a large faint blue glow, a white ring, and a walking person icon.

---

### `Navee/View/Components/IconPicker.swift`

**What it does:** The horizontal scrollable row of icons in the Edit Point screen.

**`IconPickerCell`** — one icon button. When selected:
- Background fills with the icon's colour
- A coloured border appears
- The icon scales up by 8% (`scaleEffect(1.08)`)
- Icon colour changes to white

**`Equatable`** conformance on `IconPickerCell` — SwiftUI uses this to skip redrawing cells that haven't changed. Only the cell whose `isSelected` state changed gets redrawn. This improves performance.

---

### `Navee/View/Components/PinIconBox.swift`

**What it does:** A small square box showing an icon. Used in list rows and the detail card header. Shows the icon in its colour on a black background.

```swift
var size: CGFloat = 40       // box size — default 40, can be overridden
var iconSize: CGFloat = 30   // icon size inside the box
```
These have **default values**, so callers can use `PinIconBox(emoji: "mappin")` without specifying sizes, or override them with `PinIconBox(emoji: "mappin", size: 44)`.

---

### `Navee/View/Components/LocationMetaRow.swift`

**What it does:** A one-line info strip showing distance + altitude. Reused in both `SavedMarkRow` and `BottomPinDetailView`.

```
125 m · 39 masl
```
`masl` = meters above sea level.

---

### `Navee/View/Components/InfoRow.swift`

**What it does:** A simple two-column row: label on the left, value on the right. Used in the Edit Point info section.

```
Distance          125 m away
Altitude          1500 masl
Coordinates       -6.2, 106.8166
Saved             Today, 14.28
```

---

### `Navee/View/Components/EmptySavedMarksView.swift`

**What it does:** A placeholder shown in the "Saved Points" list when no points have been saved yet. Shows a grey pin icon and the text "No points saved yet."

---

### `Navee/View/Components/BottomNavCard.swift`

**What it does:** The card at the bottom of the compass navigation screen. Shows destination name, distance, and a progress bar of checkpoints.

**`MRTProgressLine`** — the row of dots connected by lines, like a metro (MRT) map. Shows your progress through all the waypoints. When there are more than 5 points, it only shows 5 at a time with `···` on the edges to indicate more exist.

**`EndNavButton`** — the red "End Navigate" button. Uses `ModalButtonStyle` which slightly shrinks and dims the button when pressed.

---

### `Navee/View/Compass/CompassView.swift`

**What it does:** The circular compass graphic in the navigation screen.

**Parts:**
- `CompassDial` — draws the degree tick marks (360 of them) and cardinal labels (N, NE, E, SE, S, SW, W, NW) using a `Canvas` (a lower-level drawing surface for performance)
- `DirectionCone` — the glowing triangle pointing up, green when on track, white when off track
- `NorthPointer` — small red triangle always pointing to true north
- `DestinationPin` — a teardrop pin that orbits inside the compass, showing where the destination is relative to you. When on track, it shows the full pin. When off track, it's a faint dot.
- `UserDot` — three concentric circles in the center (faint blue, white, blue) representing you

**`rotationEffect(.degrees(-nav.userHeading))`** — the whole inner layer rotates opposite to the direction you're facing. This makes it feel like the compass dial spins as you turn.

---

### `Navee/View/Compass/StatusLabel.swift`

**What it does:** The large text below the compass. Shows one of four states:
- `"Finding Location"` — waiting for GPS
- `"Heading Right"` — facing the right direction (green)
- `"Slightly Off"` — turned the wrong way (red)
- `"Arrived!"` — within 10 metres of destination (yellow)

---

### `Navee/View/Compass/ArrivalFlashOverlay.swift`

**What it does:** A brief "Checkpoint" notification that flashes on screen when you reach an intermediate waypoint. Fades in quickly, stays for about 1 second, then fades out.

```swift
.scaleEffect(0.88 + 0.12 * opacity)
```
As `opacity` goes from 0 → 1, the scale goes from 0.88 → 1.0. This gives a slight pop-in feel.

---

## Styles

### `Navee/Styles/GlassButtonStyle.swift`

**What it does:** Custom button styles that control how buttons look when pressed.

**`GlassButtonStyle`** — shrinks to 93% when pressed, springs back when released. Used for the circular toolbar buttons.

**`DestructiveGlassButtonStyle`** — same spring effect but also dims the red background. Used for dangerous actions like Delete.

---

## How Everything Connects

```
Navee.swift (starts the app)
  └── MainView
        ├── LocationTracker (GPS sensor, runs in background)
        ├── Map + Pins (DynamicTearDropPin, FootstepMarker)
        ├── StartOverlay (shown before tracking starts)
        ├── TrackingToolbar (Add Mark, Saved Points buttons)
        └── UnifiedMarkSheet (the bottom sheet)
              ├── list → SavedMarkRow (one row per location)
              ├── detail → BottomPinDetailView (mini card + photo preview)
              └── edit → ModifyPin
                          ├── IconPickerSection (icon chooser)
                          ├── PointPhotoPickerView (take/pick photo)
                          └── InfoRow (read-only data rows)

CompassNavigationView (separate full-screen, opened from BottomPinDetailView)
  ├── LocationTracker (second instance, only during navigation)
  ├── CompassView (the spinning compass graphic)
  ├── StatusLabel ("Heading Right" / "Slightly Off" etc.)
  └── BottomNavCard (destination name, distance, MRT progress dots)
```

---

## The Photo Feature — How It All Works Together

1. User opens **Edit Point** → `ModifyPin` shows `PointPhotoPickerView`
2. User taps the camera box → action sheet appears: Take Photo / Choose from Library
3. User takes/picks a photo → bytes saved into `draft.photoData`
4. User taps ✓ → `location = draft` — the real `Location` now has `photoData`
5. User closes the sheet and taps the pin on the map → `BottomPinDetailView` checks `location.photoData`
6. If photo exists → displayed as a 130pt tall image in the detail card
7. `UnifiedMarkSheet` also checks for a photo → uses the taller 370pt detent so everything fits

---

*Generated for Navee — Challenge 2, Jungler Team*
