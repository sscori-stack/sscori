# Bug Report — EBS 영단어 학습 Client

**Date:** 2026-03-20
**Scope:** `src/client/` (client-only, no backend)
**Analyst:** QA Agent

---

## Summary

| Severity | Found | Fixed |
|----------|-------|-------|
| HIGH     | 3     | 3     |
| MEDIUM   | 3     | 1     |
| LOW      | 2     | 0     |
| **Total**| **8** | **4** |

---

## HIGH Severity (all fixed)

### BUG-001: Double event binding on bottom navigation buttons
- **File:** `js/screens/home.js:35` + `js/main.js:23`
- **Description:** `initHome()` used `document.querySelectorAll('[data-nav]')` which matches BOTH the home screen menu grid cells AND the bottom navigation buttons. Since `main.js` separately binds click handlers to `.bottom-nav .nav-btn`, every bottom nav button received two click handlers. The home button specifically fired `nav('home')` (slide-left animation) instead of the correct `goHome()` (direct transition), producing visually incorrect screen transitions.
- **Impact:** Incorrect animation when tapping the home nav button. Other nav buttons fire `nav()` twice per click (guarded by `current === to` check so functionally harmless, but wasteful).
- **Fix:** Changed selector from `'[data-nav]'` to `'.menu-grid [data-nav]'` to scope binding to menu cells only.

### BUG-002: App crash when Web Speech API is unavailable
- **File:** `js/audio.js:40-41`
- **Description:** Module-level calls `window.speechSynthesis.getVoices()` and `window.speechSynthesis.onvoiceschanged = () => {}` execute during import without checking if `speechSynthesis` exists. On browsers/environments where the Web Speech API is not available (e.g., some Android WebViews, Node.js test environments), this throws `TypeError: Cannot read properties of undefined (reading 'getVoices')`, crashing the entire application since `audio.js` is imported by multiple modules.
- **Impact:** Complete app failure on unsupported browsers.
- **Fix:** Wrapped in `if (window.speechSynthesis)` guard.

### BUG-003: Redundant/fragile import path in main.js
- **File:** `js/main.js:1`
- **Description:** Import path `'../js/router.js'` navigates up from `js/` to `client/` then back into `js/`. While this resolves correctly (`client/js/../js/router.js` → `client/js/router.js`), it is inconsistent with all other imports in the file (which use `./` relative paths) and fragile if the directory structure changes.
- **Impact:** Confusing for developers; breaks if directory structure is reorganized.
- **Fix:** Changed to `'./router.js'`.

---

## MEDIUM Severity

### BUG-004: Duplicate import from same module (FIXED)
- **File:** `js/screens/matching.js:2-3`
- **Description:** `speak` and `sfx` are imported from `'../audio.js'` in two separate import statements. Should be a single combined import.
- **Impact:** Code style issue; no functional impact.
- **Fix:** Combined into `import { speak, sfx } from '../audio.js';`

### BUG-005: Service worker missing icon assets
- **File:** `sw.js:2-16`
- **Description:** The ASSETS array does not include `icon-192.png` or `icon-512.png`. These are referenced by `manifest.json` for PWA install but won't be cached for offline use. Additionally, the Google Fonts CSS and font files are not cached, meaning text rendering falls back to system fonts when offline.
- **Impact:** PWA install icons may not display offline. Fonts fall back to system fonts offline.
- **Status:** Not fixed — icon files don't exist in `src/client/` yet (they're in the project root). Font caching requires a different strategy (cache-on-fetch).

### BUG-006: Unused exports in router.js
- **File:** `js/router.js:8-9`
- **Description:** `getCurrent()` and `getSqTimerID()` are exported but never imported by any module. Dead code.
- **Impact:** No functional impact; increases cognitive load and bundle size marginally.
- **Status:** Not fixed — left as-is since they may be useful for future features or debugging. // BUG: unused exports getCurrent and getSqTimerID

---

## LOW Severity

### BUG-007: innerHTML used with embedded data
- **Files:** `js/screens/flashcard.js:178`, `js/screens/speedquiz.js:153`, `js/screens/matching.js:56`
- **Description:** Word data (eng/kor fields) is interpolated into HTML via template literals and inserted with `innerHTML`. While the data is hardcoded in `js/data/words.js` (not user-supplied), this pattern is technically XSS-prone if the data source ever changes.
- **Impact:** No current risk since data is static. Would become HIGH if data were fetched from an API or user input.
- **Status:** Not fixed — acceptable risk for hardcoded data. // BUG: innerHTML with interpolated data; safe only because data is hardcoded

### BUG-008: Speed quiz timer has split state
- **File:** `js/screens/speedquiz.js:8` + `js/router.js:5`
- **Description:** The speed quiz timer ID is stored in TWO places: `speedquiz.js` local variable `sqTimerID` and `router.js` state via `setSqTimerID()`. When the router clears the timer on navigation, it clears its own copy. The speedquiz module's copy becomes stale (pointing to a cleared interval). This is functionally harmless because `clearInterval` was already called, and the stale value is overwritten on the next `sqStart()`, but the split state is a maintenance hazard.
- **Impact:** No functional impact currently. Could cause subtle bugs if timer cleanup logic changes.
- **Status:** Not fixed — would require architectural refactor to centralize timer ownership. // BUG: timer state duplicated between speedquiz.js and router.js

---

## Static Analysis Checklist

| Check | Result |
|-------|--------|
| Unused imports | 0 found |
| Undefined variables | 0 found (all DOM IDs verified against index.html) |
| Missing error handling | 1 found (BUG-002, fixed) |
| Hardcoded secrets | 0 found (no API keys, tokens, or credentials) |
| API contract vs implementation | N/A (no backend API) |
| Event listener cleanup | No leaks found — innerHTML replacement GCs old listeners |
| LocalStorage edge cases | Handled via try/catch in store.js |
| Cross-module state consistency | 1 issue (BUG-008, low risk) |

---

## Files Modified

| File | Change |
|------|--------|
| `js/screens/home.js:35` | Scoped `[data-nav]` selector to `.menu-grid` |
| `js/audio.js:40-41` | Added `if (window.speechSynthesis)` guard |
| `js/main.js:1` | Fixed import path from `'../js/router.js'` to `'./router.js'` |
| `js/screens/matching.js:2-3` | Combined duplicate audio.js imports |
