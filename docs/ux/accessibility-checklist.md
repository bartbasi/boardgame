# Accessibility checklist

Owner: ux-designer. Used by developers while building, by QA, and by the UX check on every UI ticket. Target: WCAG 2.2 AA, TalkBack, VoiceOver. Draft for user review (T-003).

Automated checks (flutter_test, per screen, light and dark): `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`. Automated checks do not replace the manual items below.

## 1. Color and contrast (WCAG 1.4.3, 1.4.11, 1.4.1)

- [ ] Body text is at least 4.5:1 against its background in light and dark. Large text (18 pt, or 14 pt bold) is at least 3:1.
- [ ] Icons that carry meaning, input borders, focus indicators, chart lines, and selected states are at least 3:1 against neighbors.
- [ ] Only theme color roles are used. No hard-coded colors.
- [ ] Nothing is shown by color alone: errors have an icon and text; asking vs sold differ by word and icon; stale has a word and icon; selected tabs have a fill and a check or indicator.
- [ ] Text over the camera preview sits on an opaque pill.
- [ ] Disabled controls are visibly disabled (not the only way to know a button is unavailable: text explains why where it matters).

## 2. Touch targets (WCAG 2.5.8)

- [ ] Every tappable control is at least 48 x 48 dp, including icon buttons, clear buttons, chips, tabs, range segments, and the torch toggle.
- [ ] Targets have at least 8 dp between them where practical.
- [ ] No action depends on swipe, long press, or drag alone. Each has a button or menu alternative.

## 3. Text size (WCAG 1.4.4, 1.4.10)

- [ ] At text scale 2.0, in compact, medium, and expanded sizes, nothing is clipped, overlaps, or overflows; no "RenderFlex overflow" in tests.
- [ ] Names and titles wrap fully. Ellipsis is used only in the app bar title.
- [ ] Layouts switch (stack buttons, stack fields) before they would truncate.
- [ ] Rotation does not hide content or controls.
- [ ] Nothing depends on a fixed height for text containers.

## 4. Semantics and labels (WCAG 1.1.1, 4.1.2)

- [ ] Every icon button, image, and chart has a semantic label from copy.md. Decorative images are excluded from semantics.
- [ ] Rows are a single node with a full label (name, year, list, price line) and a clear action.
- [ ] Toggles and tabs expose their state (selected, on, off).
- [ ] Headings are marked for screen title and section titles.
- [ ] Text fields have visible labels, helper and error text exposed as hints.
- [ ] Buttons that open outside the app say so (for example View on eBay).
- [ ] Custom actions exist wherever a row has a menu (move, edit, remove, refresh).

## 5. Focus order and keyboard (WCAG 2.4.3, 2.1.1)

- [ ] Focus order matches reading order, as listed in each screen spec section 7.
- [ ] Sheets and dialogs take focus to their title and return it to the trigger on close.
- [ ] After an error, focus stays in the field (manual entry) or moves to the error title (full-screen errors).
- [ ] All controls work with a hardware keyboard and switch access. Visible focus indicator on every focusable control.
- [ ] Back and Escape close sheets and menus.

## 6. Announcements (WCAG 4.1.3)

- [ ] Scan success: polite announcement `scanner.success` plus haptic.
- [ ] Manual entry errors: assertive announcement.
- [ ] Loading, empty, and error state changes: announced once, politely.
- [ ] Snackbars (added, moved, removed, saved match, export done, refresh failed): live region.
- [ ] Saved indicator on edit: polite, at most once per 2 seconds.
- [ ] Search result count and collection filter result count: polite.
- [ ] Offline banner: announced once when it appears.
- [ ] Progress for export, import, and backup: at start, at 50 percent, on finish.

## 7. Charts and data (WCAG 1.1.1, 1.3.1)

- [ ] Every chart has a visible text summary and a semantic label that contains it.
- [ ] A table alternative exists and is one tap away.
- [ ] Points are not individually focusable; the table covers details.
- [ ] Range selection announces the new summary.
- [ ] Gaps are described in text; zeros are never invented.

## 8. Motion and haptics (WCAG 2.3.3)

- [ ] With the system "reduce motion" setting on: no shimmer, no flash on scan success, no chart draw animation, no animated sheet bounce (use fades or none).
- [ ] No content flashes more than three times per second.
- [ ] Haptics are supplemental; every haptic has a visual and spoken equivalent.

## 9. Permissions and errors

- [ ] Camera and photo permission denial explains why and offers Open settings; all non-camera paths still work.
- [ ] Errors use plain language, say what to do, and have a Retry. No codes, no exception text.
- [ ] Offline shows saved data with a "Last updated" label, not a blank error.

## 10. Pricing accessibility

- [ ] Each price is read with amount, asking or sold, source, sample size, and age in one grouped announcement.
- [ ] The asking and sold badges are different in words and icons.
- [ ] Disclosure text is read in order near the listings.

## 11. Device checks (manual, per release candidate)

- [ ] TalkBack on an Android phone: complete scan, search, add to collection, view prices, open eBay.
- [ ] VoiceOver on an iPhone: same flows.
- [ ] Android font size and display size at maximum.
- [ ] iOS Larger Accessibility Sizes at maximum.
- [ ] Dark and light themes, bright and dim rooms (scanner contrast).
- [ ] Reduce motion on.
