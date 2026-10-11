# Screen spec: Scanner

Status: draft for user review (T-003). Ticket: T-030. Flow: flows/scan-to-game-detail.md.

## 1. Purpose and entry points

Read a UPC-A, EAN-13, or EAN-8 barcode from a game box and open the lookup. This is the start destination of the app (the Scan tab). Entry points: app launch, the Scan destination, "Scan a barcode" actions on empty states (Search, Collection), "Scan again" on lookup-result, and "Scan instead" on manual-entry.

Rules that apply in every state:

- Manual entry (`scanner.actionManual`) and title search (`scanner.actionSearch`) are always visible and one tap away. They are never hidden behind the camera, the permission panel, or an error.
- The system camera permission prompt appears only when this screen is first opened, never at app start or on another screen.
- Nothing here blocks use of the rest of the app.

## 2. Layout

Camera preview fills the area between the app bar and the ScanActionBar. The frame, hint pill, and TorchToggle sit on top of the preview.

| Size | Layout |
|---|---|
| Compact portrait (390 x 844) | App bar (title `scanner.title`). Viewfinder fills the height. Hint pill 24 dp below the top of the preview. TorchToggle top-right of the preview. ScanActionBar docked under the preview: two buttons side by side, each 48 dp tall, equal width. NavigationBar below. |
| Phone landscape (844 x 390) | Rail at leading edge. Viewfinder takes the left 60% of the content. Right 40% column holds the hint text and the two action buttons stacked (full width, 48 dp each), centered vertically. |
| Medium (744 x 1133 / 1133 x 744) | Rail. Preview fills the content, max aspect cropped to the frame; the scan frame stays 70% of the shorter side. ScanActionBar below the preview, buttons capped at 280 dp each, centered. |
| Expanded (1280 x 800) | Rail. Preview takes the center, capped at 720 dp wide and centered; scrim fills the rest with surface color (not a stretched camera image). ScanActionBar below the preview, centered. |

The scan frame is a rounded rectangle at 2.5:1, 70% of the preview's shorter side, centered slightly above the middle.

At 200% text: the two action buttons stack vertically (full width) if the labels would wrap past 2 lines; the preview shrinks to make room, never below 40% of the content height. The hint pill grows and wraps.

## 3. Components

ScannerViewfinder, TorchToggle, ScanActionBar, PermissionPanel, AdaptiveScaffold, Snackbar. See docs/ux/components.md.

## 4. States

| State | What the user sees |
|---|---|
| Starting | Preview area in surfaceContainerHighest with a small progress indicator and `scanner.starting`. ScanActionBar visible. Lasts under 1 s on a granted device. |
| Permission requesting (first open) | PermissionPanel with `scanner.permission.requestingTitle` and `requestingBody`, shown behind the system prompt, so the user sees why the prompt is there. No extra tap is needed. The system prompt text uses `scanner.iosUsageDescription` (iOS) and the system default (Android). When the prompt closes: granted goes to Scanning; denied goes to Denied. |
| Scanning | Live preview, frame, hint `scanner.hint`, TorchToggle (only if the device has a torch). After 8 s with no valid detection, the hint changes to `scanner.hintSlow` (no sound, no blocking). |
| Detected (success feedback) | One haptic (the platform's light impact). The frame flashes in primary and shows a check icon for 300 ms (no flash with reduce motion, the check only). The screen reader hears `scanner.success`. Then the app opens lookup-result. Detections of other formats (QR, UPC-E, Code 128) and codes with a bad check digit are ignored with no feedback. The same code is ignored for 2 s after a detection [ASSUMPTION]. |
| Denied (can ask again) | PermissionPanel: `scanner.denied.title`, `scanner.denied.body`, primary action `scanner.denied.allow` (asks again). ScanActionBar visible. |
| Permanently denied (iOS: denied after the first prompt; Android: "don't ask again") | PermissionPanel: `scanner.permanentlyDenied.title`, `scanner.permanentlyDenied.body`, primary action `common.openSettings` (opens the app's page in system settings). When the user returns from settings with the permission on, the camera starts without another tap. |
| Restricted (iOS parental or device policy) | PermissionPanel: `scanner.denied.title`, `scanner.restricted.body`, no action button except the ScanActionBar (settings cannot change this). |
| Camera unavailable | PermissionPanel: `scanner.unavailable.title`, `scanner.unavailable.body`, primary action `common.retry`. ScanActionBar visible. |
| Offline | Scanning works. No banner here. The lookup-result screen handles the offline case (a stored match opens the game; otherwise a clear offline message). |
| Paused | App in background or another tab selected: camera stops; it restarts when the user returns. The preview shows the starting state for under 1 s. |
| Empty / loading / partial | Not applicable beyond the above. |

Torch states: off, on, unavailable (hidden). The toggle is disabled while the camera starts.

## 5. Interactions and navigation

- Tap `scanner.actionManual`: push manual-entry. Tap `scanner.actionSearch`: switch to the Search destination with the keyboard open.
- Tap TorchToggle: toggles the torch; the icon and label change; the state is announced ("Torch is on").
- A valid detection pushes lookup-result with the normalized code. Back from lookup-result returns here with the camera live again and the same code allowed again.
- A matched lookup replaces the lookup-result with game detail in the stack, so Back from game detail returns to this scanner.
- Permission buttons: "Allow camera" re-requests; "Open settings" leaves the app; returning re-checks the permission automatically.
- Switching tabs or backgrounding the app stops the camera; coming back restarts it.
- No tap gestures on the preview (no tap-to-focus control shown in v1 [ASSUMPTION]); autofocus is automatic.

## 6. Copy

`scanner.title`, `scanner.hint`, `scanner.hintSlow`, `scanner.viewfinderLabel`, `scanner.actionManual`, `scanner.actionSearch`, `scanner.torchOn`, `scanner.torchOff`, `scanner.torchLabelOn`, `scanner.torchLabelOff`, `scanner.success`, `scanner.permission.*`, `scanner.denied.*`, `scanner.permanentlyDenied.*`, `scanner.restricted.body`, `scanner.unavailable.*`, `scanner.starting`, `scanner.iosUsageDescription`, `common.openSettings`, `common.retry`.

## 7. Accessibility

- Focus order: app bar title, TorchToggle (if present), PermissionPanel or viewfinder summary, `scanner.actionManual`, `scanner.actionSearch`, then navigation. The two actions are reachable before the user has to work out the camera.
- The viewfinder has the label `scanner.viewfinderLabel`. A blind user can scan by sweeping the box; success is announced as a polite live region with `scanner.success` and heard with the haptic. A route is also given: the manual-entry button is the second focus stop.
- Permission panel title is a heading; panel changes are announced (polite) when the state changes.
- Torch toggle: label from `scanner.torchOn` / `scanner.torchOff`, role switch, state spoken.
- Contrast: hint text sits on an opaque pill using surface and onSurface (at least 4.5:1) so it works on any camera image. Frame and corner marks use white-on-scrim in light and dark themes as functional graphics; the scrim is at least 3:1 against the brightest expected image area and the frame is also marked by the pill text. [A manual device check is listed in the handoff.]
- Touch targets: torch toggle 48 dp, action buttons 48 dp tall, panel buttons 48 dp.
- Haptics are supplemental; every success also has a visual and spoken signal. Respect the system haptics setting.
- Reduce motion: no flash, no scan-line animation (the frame has none anyway).
- Text at 200%: action buttons stack; panel text wraps; no clipping.

## 8. Golden cases
The camera preview is replaced by a neutral placeholder in all goldens (T-030 criterion 14). Total: 8. The panel states (denied, permanently denied, restricted, unavailable) share one layout, so one golden covers the layout and a second covers dark; the rest are covered by widget tests (state, text, and the always-visible manual and search actions).

| File | Notes |
|---|---|
| scanner_scanning_light_compact.png | Hint, frame, torch toggle, both actions |
| scanner_scanning_dark_compact.png | |
| scanner_scanning_light_landscape.png | Phone landscape two-column layout |
| scanner_requesting_light_compact.png | Rationale behind the system prompt |
| scanner_detected_light_compact.png | Check on frame |
| scanner_permanentlydenied_light_compact.png | Panel with Open settings, both actions visible |
| scanner_denied_dark_compact.png | Panel in dark with Allow camera |
| scanner_permanentlydenied_text200_dark_compact.png | Actions stacked, panel wrapped |

## 9. What PM and reviewers should check

- Manual entry and search buttons are visible in every golden, including denied and unavailable.
- Permission explanation says why the camera is needed, and the settings button exists in permanently denied.
- No dialog or modal appears before the camera.
- Success has haptic, visual, and spoken feedback.
- Only UPC-A, EAN-13, and EAN-8 act; bad check digits do nothing.
- Open questions: whether the "Allow camera" button should be shown when Android reports "denied" without "don't ask again" (spec says yes); whether a tap-to-focus control is needed on the reference devices (PRD Q7); Android ML Kit disclosure (PRD Q4).
