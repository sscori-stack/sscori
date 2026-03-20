import { getProg, getDont } from '../store.js';
import { nav } from '../router.js';

export function updateHome() {
  const prog = getProg(), dont = getDont();
  let sets = 0, words = 0;
  Object.values(prog).forEach(p => { if (p.done) { sets++; words += p.know || 0; } });

  document.getElementById('hsSets').textContent = sets;
  document.getElementById('hsWords').textContent = words;
  document.getElementById('hsReview').textContent = dont.length;
  document.getElementById('reviewBadge').style.display = dont.length ? 'block' : 'none';

  const strip = document.getElementById('reviewStrip');
  strip.innerHTML = dont.length
    ? `<div class="review-strip" id="reviewStripBtn"><div class="rs-icon">🔁</div><div class="rs-body"><div class="rs-title">복습할 단어 ${dont.length}개</div><div class="rs-sub">모르는 단어를 다시 학습해봐요!</div></div><span>›</span></div>`
    : '';

  const btn = document.getElementById('reviewStripBtn');
  if (btn) btn.addEventListener('click', goReviewFromHome);
}

let goReviewCallback = null;

export function setGoReviewCallback(cb) {
  goReviewCallback = cb;
}

function goReviewFromHome() {
  nav('fc');
  if (goReviewCallback) setTimeout(goReviewCallback, 80);
}

export function initHome() {
  // FIX: Scope to .menu-grid to avoid double-binding bottom nav buttons
  document.querySelectorAll('.menu-grid [data-nav]').forEach(el => {
    const target = el.dataset.nav;
    if (target) {
      el.addEventListener('click', () => nav(target));
    }
  });

  document.getElementById('reviewMenuCell').addEventListener('click', goReviewFromHome);

  updateHome();
}
