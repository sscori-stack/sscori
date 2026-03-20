# EBS 영단어 학습 — Client

## Component Tree

```
index.html
├── css/app.css                  # All styles (tokens, screens, effects)
├── js/main.js                   # App entry point, wires everything together
│   ├── js/router.js             # Screen navigation (nav, goHome)
│   ├── js/store.js              # localStorage wrapper (progress, don't-know list)
│   ├── js/audio.js              # TTS (speak) + sound effects (sfx)
│   ├── js/utils.js              # shuffle, fxAt, confetti, showBanner
│   └── js/data/words.js         # 800 word dataset + SETS (chunks of 20)
│   ├── js/screens/home.js       # Home screen (stats, menu grid, review strip)
│   ├── js/screens/flashcard.js  # Flashcard study mode (set picker, card flip, results)
│   ├── js/screens/matching.js   # Matching game (pair selection, scoring, lives)
│   └── js/screens/speedquiz.js  # Speed quiz (timed 4-choice, combo system)
├── sw.js                        # Service worker for offline caching
└── manifest.json                # PWA manifest
```

## Environment Variables

None required. This is a fully client-side application with no backend.
All data is embedded in `js/data/words.js` and persisted in `localStorage`.

## How to Run Locally

### Option 1: Any static file server

```bash
cd src/client
npx serve .
# or
python3 -m http.server 8000
# or
php -S localhost:8000
```

Then open `http://localhost:8000` (or the port shown).

### Option 2: Open directly

ES modules require a server (not `file://`), so use any of the above methods.

### PWA Icons

Copy `icon-192.png` and `icon-512.png` from the project root into `src/client/`
for PWA install support, or update `manifest.json` paths accordingly.

## Architecture Notes

- **No build step** — vanilla ES modules loaded directly by the browser
- **No framework** — pure DOM manipulation with event delegation
- **No external dependencies** — only Google Fonts loaded via CDN
- **Offline-first** — service worker caches all assets on first visit
- **Mobile-first** — max-width 480px, portrait orientation
- **TTS** — uses Web Speech API for English pronunciation
- **Sound effects** — generated via Web Audio API oscillators (no audio files)
