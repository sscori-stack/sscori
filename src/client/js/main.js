import { nav, goHome, onNavigate } from '../js/router.js';
import { initHome, updateHome, setGoReviewCallback } from './screens/home.js';
import { initFlashcard, fcInit, activateReviewTab } from './screens/flashcard.js';
import { initMatching, mtSetupShow } from './screens/matching.js';
import { initSpeedQuiz, sqShowSetup } from './screens/speedquiz.js';

// Register navigation callbacks
onNavigate('home', updateHome);
onNavigate('fc', fcInit);
onNavigate('mt', mtSetupShow);
onNavigate('sq', sqShowSetup);

// Wire review shortcut from home screen
setGoReviewCallback(activateReviewTab);

// Initialize all screens
initHome();
initFlashcard();
initMatching();
initSpeedQuiz();

// Bottom nav event listeners
document.querySelectorAll('.bottom-nav .nav-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    const target = btn.dataset.nav;
    if (target === 'home') goHome();
    else nav(target);
  });
});

// Back buttons
document.getElementById('fcBack').addEventListener('click', goHome);

// Install prompt
let installEvt = null;
window.addEventListener('beforeinstallprompt', e => {
  e.preventDefault();
  installEvt = e;
  document.getElementById('installBar').classList.add('show');
});

document.getElementById('installBtn').addEventListener('click', () => {
  if (!installEvt) return;
  installEvt.prompt();
  installEvt.userChoice.then(() => {
    installEvt = null;
    document.getElementById('installBar').classList.remove('show');
  });
});

document.getElementById('installDismiss').addEventListener('click', () => {
  document.getElementById('installBar').classList.remove('show');
});

// Service worker
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('./sw.js').catch(() => {});
}
