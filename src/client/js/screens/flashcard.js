import { W, SETS } from '../data/words.js';
import { getProg, setProg, getDont, setDont } from '../store.js';
import { speak } from '../audio.js';
import { fxAt, confetti } from '../utils.js';
import { updateHome } from './home.js';

let fcWords = [], fcIdx = 0, fcKL = [], fcDL = [], fcFlipped = false, fcBusy = false, fcSetI = -1, fcIsRev = false;

export function initFlashcard() {
  document.querySelectorAll('[data-fc-tab]').forEach(btn => {
    btn.addEventListener('click', () => fcTabMode(btn.dataset.fcTab, btn));
  });

  document.getElementById('fcFront').addEventListener('click', fcFlip);
  document.getElementById('fcBackFace').addEventListener('click', fcFlip);
  document.getElementById('fcSpeakBtn').addEventListener('click', (e) => {
    e.stopPropagation();
    speak(fcWords[fcIdx].eng);
  });
  document.getElementById('fcMarkKnow').addEventListener('click', () => fcMark(true));
  document.getElementById('fcMarkDont').addEventListener('click', () => fcMark(false));
  document.getElementById('fcRRevBtn').addEventListener('click', fcDoReview);
  document.getElementById('fcRestartBtn').addEventListener('click', fcRestart);
  document.getElementById('fcBackSetsBtn').addEventListener('click', fcBackSets);

  // Swipe support
  let fcTX = 0;
  const scene = document.getElementById('fcScene');
  scene.addEventListener('touchstart', e => { fcTX = e.touches[0].clientX; }, { passive: true });
  scene.addEventListener('touchend', e => {
    const dx = e.changedTouches[0].clientX - fcTX;
    if (Math.abs(dx) > 50) {
      if (!fcFlipped) { fcFlip(); return; }
      fcMark(dx < 0);
    }
  }, { passive: true });
}

export function fcInit() {
  document.getElementById('fcSets').style.display = 'block';
  document.getElementById('fcStudy').style.display = 'none';
  document.getElementById('fcResult').classList.remove('on');
  fcRenderSets('all');
}

export function fcTabMode(m, btn) {
  document.querySelectorAll('.set-tab').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  fcRenderSets(m);
}

export function activateReviewTab() {
  const btn = document.querySelector('[data-fc-tab="review"]');
  if (btn) fcTabMode('review', btn);
}

function fcRenderSets(m) {
  const prog = getProg(), dont = getDont(), g = document.getElementById('fcSetGrid');
  g.innerHTML = '';

  if (m === 'review') {
    if (!dont.length) {
      g.innerHTML = `<div class="empty-state" style="grid-column:1/-1"><div class="ei">🎉</div><div class="et">모르는 단어가 없어요!<br>전체 학습을 먼저 해봐요.</div></div>`;
      return;
    }
    for (let i = 0; i < dont.length; i += 20) {
      const chunk = dont.slice(i, i + 20), n = Math.floor(i / 20) + 1;
      const c = document.createElement('div');
      c.className = 'set-cell prog';
      c.innerHTML = `<span class="sc-num">복${n}</span><span class="sc-range">${chunk.length}개</span><div class="sc-pct">🔁</div>`;
      c.addEventListener('click', () => fcStart(chunk, `복습 ${n}`, true));
      g.appendChild(c);
    }
    return;
  }

  SETS.forEach((set, i) => {
    const key = `set_${i}`, p = prog[key], done = p && p.done, inprog = p && !p.done;
    const c = document.createElement('div');
    c.className = 'set-cell' + (done ? ' done' : inprog ? ' prog' : '');
    const s = i * 20 + 1, e = Math.min(s + 19, W.length), pct = p ? Math.round(p.know / 20 * 100) : 0;
    c.innerHTML = `<span class="sc-num">세트${i + 1}</span><span class="sc-range">${s}~${e}</span><div class="sc-pct">${done ? `✅${pct}%` : inprog ? `▶${pct}%` : '🆕'}</div>`;
    c.addEventListener('click', () => fcStart(set, `세트 ${i + 1}`, false, i));
    g.appendChild(c);
  });
}

function fcStart(words, title, isRev = false, si = -1) {
  fcWords = [...words]; fcSetI = si; fcIsRev = isRev;
  fcIdx = 0; fcKL = []; fcDL = []; fcFlipped = false; fcBusy = false;
  document.getElementById('fcTopTitle').textContent = title;
  document.getElementById('fcSets').style.display = 'none';
  document.getElementById('fcStudy').style.display = 'flex';
  document.getElementById('fcResult').classList.remove('on');
  fcCard(); speak(fcWords[0].eng);
}

function fcCard() {
  const w = fcWords[fcIdx];
  fcFlipped = false;
  document.getElementById('fc3d').classList.remove('flip');
  const ew = document.getElementById('fcEng');
  ew.textContent = w.eng;
  ew.className = 'f-word' + (w.eng.length > 12 ? ' sm' : w.eng.length > 8 ? ' md' : '');
  document.getElementById('fcBEng').textContent = w.eng;
  const kw = document.getElementById('fcKor');
  kw.textContent = w.kor;
  kw.className = 'f-kor' + (w.kor.length > 7 ? ' sm' : '');
  document.getElementById('fcTopRight').textContent = `${fcIdx + 1}/${fcWords.length}`;
  document.getElementById('fcK').textContent = fcKL.length;
  document.getElementById('fcD').textContent = fcDL.length;
  document.getElementById('fcProg').style.width = (fcIdx / fcWords.length * 100) + '%';
}

function fcFlip() {
  if (fcBusy) return;
  fcFlipped = !fcFlipped;
  document.getElementById('fc3d').classList.toggle('flip', fcFlipped);
  if (fcFlipped) speak(fcWords[fcIdx].eng);
}

function fcMark(ok) {
  if (fcBusy) return;
  fcBusy = true;
  const w = fcWords[fcIdx];
  if (ok) { fcKL.push(w); fxAt(document.getElementById('fc3d'), '✅ 알아요!', '#22c55e'); }
  else { fcDL.push(w); fxAt(document.getElementById('fc3d'), '❌ 몰라요', '#ef4444'); }

  const wrap = document.getElementById('fc3d');
  wrap.style.cssText = 'transition:transform .26s ease,opacity .26s ease;transform:' + (ok ? 'translateX(-105%)' : 'translateX(105%)') + ';opacity:0;';

  setTimeout(() => {
    wrap.style.cssText = '';
    fcIdx++;
    if (fcIdx >= fcWords.length) { fcBusy = false; fcFinish(); return; }
    fcCard(); speak(fcWords[fcIdx].eng);
    requestAnimationFrame(() => setTimeout(() => { fcBusy = false; }, 60));
  }, 280);
}

function fcFinish() {
  const prog = getProg();
  if (!fcIsRev && fcSetI >= 0) {
    prog[`set_${fcSetI}`] = { know: fcKL.length, dont: fcDL.length, done: true, total: fcWords.length };
    setProg(prog);
  }
  const ex = getDont();
  if (fcIsRev) {
    const ke = new Set(fcKL.map(w => w.eng)), se = new Set(fcWords.map(w => w.eng));
    setDont(ex.filter(w => !ke.has(w.eng) || !se.has(w.eng)));
  } else {
    const ee = new Set(ex.map(w => w.eng)), ke = new Set(fcKL.map(w => w.eng));
    setDont([...ex.filter(w => !ke.has(w.eng)), ...fcDL.filter(w => !ee.has(w.eng))]);
  }
  fcShowRes();
}

function fcShowRes() {
  document.getElementById('fcStudy').style.display = 'none';
  const tot = fcWords.length, k = fcKL.length, d = fcDL.length, pct = Math.round(k / tot * 100);
  let em, tt;
  if (pct === 100) { em = '🏆'; tt = '완벽해요!'; }
  else if (pct >= 80) { em = '🌟'; tt = '잘했어요!'; }
  else if (pct >= 50) { em = '👍'; tt = '좋아요!'; }
  else { em = '💪'; tt = '파이팅!'; }

  document.getElementById('fcREmoji').textContent = em;
  document.getElementById('fcRTitle').textContent = tt;
  document.getElementById('fcRPct').textContent = pct + '%';
  document.getElementById('fcRK').textContent = k;
  document.getElementById('fcRD').textContent = d;
  document.getElementById('fcRT').textContent = tot;

  const dl = document.getElementById('fcRList');
  dl.innerHTML = !fcDL.length
    ? '<div style="text-align:center;color:var(--grn);padding:8px;font-size:.85rem">🎉 모르는 단어 없음!</div>'
    : '<div style="font-size:.7rem;color:var(--red);margin-bottom:6px;font-weight:700">❌ 복습할 단어 (' + fcDL.length + '개)</div>'
      + fcDL.map(w => `<div class="dont-row"><b>${w.eng}</b><span style="color:var(--muted)">${w.kor}</span></div>`).join('');

  document.getElementById('fcRRevBtn').style.display = fcDL.length ? 'block' : 'none';
  document.getElementById('fcResult').classList.add('on');
  if (pct >= 80) confetti();
}

function fcDoReview() { fcStart(fcDL, '복습 세션', true); }

function fcRestart() {
  fcIdx = 0; fcKL = []; fcDL = []; fcFlipped = false; fcBusy = false;
  document.getElementById('fcResult').classList.remove('on');
  document.getElementById('fcStudy').style.display = 'flex';
  fcCard(); speak(fcWords[0].eng);
}

function fcBackSets() {
  document.getElementById('fcResult').classList.remove('on');
  document.getElementById('fcStudy').style.display = 'none';
  document.getElementById('fcSets').style.display = 'block';
  fcRenderSets('all');
  updateHome();
}
