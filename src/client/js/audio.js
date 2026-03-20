let _ac;
const AC = () => {
  if (!_ac) _ac = new (window.AudioContext || window.webkitAudioContext)();
  return _ac;
};

function bip(f, type, dur, vol = .18, dl = 0) {
  try {
    const a = AC(), o = a.createOscillator(), g = a.createGain();
    o.connect(g); g.connect(a.destination);
    o.type = type; o.frequency.value = f;
    g.gain.setValueAtTime(vol, a.currentTime + dl);
    g.gain.exponentialRampToValueAtTime(.001, a.currentTime + dl + dur);
    o.start(a.currentTime + dl); o.stop(a.currentTime + dl + dur);
  } catch { /* audio not available */ }
}

export const sfx = {
  ok: () => { bip(523, 'sine', .1, .2); bip(659, 'sine', .1, .2, .1); bip(784, 'sine', .18, .22, .2); },
  no: () => bip(180, 'sawtooth', .28, .16),
  combo: () => [523, 659, 784, 1047].forEach((f, i) => bip(f, 'sine', .14, .2, i * .08)),
  clear: () => [523, 659, 784, 1047].forEach((f, i) => bip(f, 'sine', .16, .22, i * .09)),
  tick: () => bip(880, 'square', .05, .04),
  over: () => [380, 320, 270, 220].forEach((f, i) => bip(f, 'triangle', .28, .16, i * .12)),
};

export function speak(t) {
  if (!window.speechSynthesis) return;
  window.speechSynthesis.cancel();
  const u = new SpeechSynthesisUtterance(t);
  u.lang = 'en-US'; u.rate = 0.82; u.pitch = 1.05;
  const vs = window.speechSynthesis.getVoices();
  const v = vs.find(v => v.lang === 'en-US' && /samantha|karen|victoria|zira/i.test(v.name))
    || vs.find(v => v.lang === 'en-US') || vs.find(v => v.lang.startsWith('en'));
  if (v) u.voice = v;
  window.speechSynthesis.speak(u);
}

// FIX: Guard against missing speechSynthesis API before accessing
if (window.speechSynthesis) {
  window.speechSynthesis.getVoices();
  window.speechSynthesis.onvoiceschanged = () => {};
}
