export function shuffle(a) {
  const b = [...a];
  for (let i = b.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [b[i], b[j]] = [b[j], b[i]];
  }
  return b;
}

export function fxAt(el, txt, col) {
  const r = el.getBoundingClientRect();
  const d = document.createElement('div');
  d.className = 'fx-msg';
  d.style.cssText = `left:${r.left + r.width / 2 - 24}px;top:${r.top + r.height * .3}px;color:${col};`;
  d.textContent = txt;
  document.body.appendChild(d);
  setTimeout(() => d.remove(), 900);
}

export function confetti(n = 22) {
  const C = ['#22c55e', '#4f46e5', '#f59e0b', '#ef4444', '#a855f7', '#ec4899'];
  for (let i = 0; i < n; i++) setTimeout(() => {
    const p = document.createElement('div');
    p.className = 'fx-conf';
    const s = 6 + Math.random() * 8;
    p.style.cssText = `left:${10 + Math.random() * 80}vw;top:0;width:${s}px;height:${s}px;background:${C[i % C.length]};border-radius:${Math.random() > .5 ? '50%' : '3px'};animation-duration:${1.2 + Math.random() * .8}s;`;
    document.body.appendChild(p);
    setTimeout(() => p.remove(), 2200);
  }, i * 32);
}

export function showBanner(txt) {
  document.querySelectorAll('.banner').forEach(e => e.remove());
  const d = document.createElement('div');
  d.className = 'banner';
  d.textContent = txt;
  document.body.appendChild(d);
  setTimeout(() => d.remove(), 2200);
}
