# EBS 영단어 학습 앱 — Product Specification

---

## 1. Project Overview

- **App Name:** EBS 영단어 학습 (EBS Vocabulary Learning)
- **Purpose:** A mobile-first Progressive Web App (PWA) that helps Korean elementary students learn the 800 essential English vocabulary words from the EBS curriculum through interactive study modes — flashcards, matching games, and speed quizzes.
- **Target Users:** Korean elementary school students (ages 8–13) and their parents/guardians who want a free, offline-capable, game-based English vocabulary study tool aligned with the national EBS curriculum.

---

## 2. Core Features (MVP only)

1. **As a student, I can browse vocabulary sets (20 words each) so that I can study in manageable chunks.**
2. **As a student, I can study flashcards (English ↔ Korean) with TTS pronunciation so that I can learn word meanings and pronunciation.**
3. **As a student, I can mark each flashcard as "know" or "don't know" so that I can track which words need more practice.**
4. **As a student, I can play a matching game (tap English ↔ Korean pairs) so that I can reinforce word associations in a fun way.**
5. **As a student, I can take a timed speed quiz (4-choice multiple choice) so that I can test recall under time pressure.**
6. **As a student, I can review only the words I marked "don't know" so that I can focus on weak spots.**
7. **As a student, I can see my overall progress (sets completed, words learned, words to review) on the home screen so that I stay motivated.**
8. **As a student, I can install the app on my phone's home screen and use it offline so that I can study anywhere without internet.**

**Out of MVP scope:** user accounts/login, leaderboards, spaced-repetition algorithm, teacher/parent dashboard, additional word sets beyond EBS 800, cloud sync across devices, gamification (badges/streaks), in-app purchase.

---

## 3. Tech Stack Decision

| Layer | Choice | Rationale |
|---|---|---|
| **Frontend** | Vanilla JS (single HTML file) | Zero build toolchain. Instant load. Target audience (kids) needs fast, lightweight UX. No framework overhead. PWA with service worker provides offline support. |
| **Backend** | None (client-only) | All 800 words are embedded in the HTML. Progress stored in `localStorage`. No server needed for MVP. |
| **Database** | `localStorage` | Simple key-value persistence. No user accounts → no need for a real database. Sufficient for single-device progress tracking. |
| **Auth** | No | MVP is a standalone single-user app. No accounts, no server. |

---

## 4. Data Models

### Word
| Field | Type | Description |
|---|---|---|
| `eng` | `string` | English word |
| `kor` | `string` | Korean translation |

### Set (derived)
| Field | Type | Description |
|---|---|---|
| index | `number` | Set number (0-based), each set = 20 words |
| words | `Word[]` | Slice of the master word list |

### Progress (`ebs_prog` in localStorage)
| Field | Type | Description |
|---|---|---|
| `set_{n}` | `object` | Per-set progress |
| `set_{n}.done` | `boolean` | Whether the set has been completed at least once |
| `set_{n}.know` | `number` | Count of words marked "know" in latest attempt |

### Don't-Know List (`ebs_dont` in localStorage)
| Field | Type | Description |
|---|---|---|
| (root) | `Word[]` | Array of words the user marked "don't know" across all sets |

---

## 5. API Contract

**No server-side API.** All logic is client-side.

### Internal Function Interface (JavaScript)

| Function | Description |
|---|---|
| `nav(to: 'home'\|'fc'\|'mt'\|'sq')` | Navigate between screens |
| `goHome()` | Return to home screen, refresh stats |
| `updateHome()` | Refresh progress stats on home screen |
| `fcInit()` | Initialize flashcard screen (show set picker) |
| `fcStart(words, title, isReview, setIndex)` | Start a flashcard session |
| `fcFlip()` | Flip current flashcard |
| `fcMark(ok: boolean)` | Mark current card know/don't-know, advance |
| `mtSetupShow()` | Show matching game set picker |
| `mtStart(setIndex)` | Start a matching game round |
| `sqShowSetup()` | Show speed quiz set picker |
| `sqStart(setIndex)` | Start a speed quiz round |
| `speak(text: string)` | Speak English text via Web Speech API |
| `ST.get(key, default)` | Read from localStorage |
| `ST.set(key, value)` | Write to localStorage |
| `getProg() / setProg(data)` | Read/write progress object |
| `getDont() / setDont(data)` | Read/write don't-know list |

---

## 6. UI Screens

### 6.1 Home Screen (`#homeScreen`)
- **Hero banner** — app mascot (📚 emoji), app name, subtitle
- **Stats row** — 3 cards: sets completed, words learned, words to review
- **Review strip** — conditional banner linking to review flashcards (shown when don't-know list > 0)
- **Menu grid** — 4 tiles:
  - 📖 플래시카드 (Flashcards)
  - 🎯 매칭게임 (Matching Game)
  - ⚡ 스피드퀴즈 (Speed Quiz)
  - 🔁 복습 (Review)

### 6.2 Flashcard Screen (`#fcScreen`)
- **Top bar** — back button, title, card counter (e.g. 3/20)
- **Tab bar** — "전체" (All) / "복습" (Review) toggle
- **Set picker grid** — set cards showing status (new/in-progress/done + percentage)
- **Study view** (after set selection):
  - 3D-flip flashcard (front: English word, back: English + Korean)
  - Know ✅ / Don't-know ❌ buttons
  - Progress bar
  - Running tallies (know count / don't-know count)
- **Result overlay** — score summary, confetti animation, "다시" (retry) / "홈" (home) buttons

### 6.3 Matching Game Screen (`#mtScreen`)
- **Top bar** — back button, title
- **Set picker grid** — same layout as flashcard set picker
- **Game view**:
  - Timer display
  - Scattered word tiles (English on left, Korean on right, or mixed)
  - Tap-to-match interaction with visual feedback (correct = green, wrong = shake)
  - Progress indicator
- **Result overlay** — time, score, combo streak

### 6.4 Speed Quiz Screen (`#sqScreen`)
- **Top bar** — back button, title
- **Set picker grid**
- **Quiz view**:
  - Countdown timer bar
  - English word prompt
  - 4 Korean answer choices
  - Score display, combo counter
- **Result overlay** — final score, accuracy, time

### 6.5 Bottom Navigation Bar (persistent)
- 4 tabs: 🏠 홈 / 📖 카드 / 🎯 매칭 / ⚡ 퀴즈
- Active tab highlighting

---

## 7. Constraints & Assumptions

1. **Single HTML file architecture.** All CSS, JS, and data are embedded in one file (~35K tokens). This is intentional for simplicity and zero-dependency deployment (e.g. GitHub Pages).
2. **No build step.** No bundler, transpiler, or package manager. Edit the HTML directly.
3. **800 words are hardcoded.** The word list (`W` array) is embedded as a JSON literal. Adding/changing words means editing the source.
4. **Mobile-first, portrait-locked.** Max width 480px. Designed for phone screens. Desktop is supported but not optimized.
5. **Offline-first via service worker** (`sw.js`). The app works without internet after first visit.
6. **TTS via Web Speech API.** Pronunciation quality depends on the device's available voices. English (en-US) is preferred; rate is slowed to 0.82 for learners.
7. **No server, no sync.** Progress is local to the device/browser. Clearing browser data loses all progress.
8. **localStorage limits.** Progress data is small (~2KB), well within the 5MB localStorage limit.
9. **PWA installable.** `manifest.json` with icons enables "Add to Home Screen" on Android/iOS.
10. **Target browser support:** Modern mobile browsers (Chrome, Safari, Samsung Internet). No IE11 support needed.
11. **Korean UI only.** All interface text is in Korean. No i18n infrastructure.
12. **Sound effects** use Web Audio API (oscillator-based). No audio files needed.
