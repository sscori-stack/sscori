const screenMap = { home: 'homeScreen', fc: 'fcScreen', mt: 'mtScreen', sq: 'sqScreen' };
const navMap = { home: 'nHome', fc: 'nFc', mt: 'nMt', sq: 'nSq' };

let current = 'home';
let sqTimerID = null;
const listeners = {};

export function getCurrent() { return current; }
export function getSqTimerID() { return sqTimerID; }
export function setSqTimerID(id) { sqTimerID = id; }

export function onNavigate(screen, callback) {
  listeners[screen] = callback;
}

export function nav(to) {
  if (current === to) return;
  window.speechSynthesis.cancel();
  if (sqTimerID) { clearInterval(sqTimerID); sqTimerID = null; }

  const prev = document.getElementById(screenMap[current]);
  const next = document.getElementById(screenMap[to]);
  prev.classList.add('offL');
  setTimeout(() => prev.classList.add('off'), 350);
  next.classList.remove('off', 'offL');
  current = to;

  document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
  const nb = document.getElementById(navMap[to]);
  if (nb) nb.classList.add('active');

  if (listeners[to]) listeners[to]();
}

export function goHome() {
  window.speechSynthesis.cancel();
  if (sqTimerID) { clearInterval(sqTimerID); sqTimerID = null; }
  if (current === 'home') return;

  const prev = document.getElementById(screenMap[current]);
  prev.classList.add('off');
  document.getElementById('homeScreen').classList.remove('off', 'offL');
  current = 'home';

  document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
  document.getElementById('nHome').classList.add('active');

  if (listeners.home) listeners.home();
}
