import { W } from '../data/words.js';
// FIX: Combined duplicate imports from audio.js
import { speak, sfx } from '../audio.js';
import { shuffle, fxAt, confetti, showBanner } from '../utils.js';
import { goHome } from '../router.js';

let mtPairs = 4, mtScore = 0, mtRounds = 0, mtLives = 3;
let mtTM = 0, mtTMiss = 0, mtStr = 0, mtBStr = 0, mtMCnt = 0, mtBusy = false;
let mtSEng = null, mtSKor = null, mtPool = [], mtRW = [];

export function initMatching() {
  document.querySelectorAll('[data-mt-diff]').forEach(btn => {
    btn.addEventListener('click', () => mtDiff(parseInt(btn.dataset.mtDiff), btn));
  });
  document.getElementById('mtStartBtn').addEventListener('click', mtStart);
  document.getElementById('mtNext').addEventListener('click', mtRound);
  document.getElementById('mtResetBtn').addEventListener('click', mtSetupShow);
  document.getElementById('mtHomeBtn').addEventListener('click', goHome);
  document.getElementById('mtBack').addEventListener('click', goHome);
}

export function mtSetupShow() {
  document.getElementById('mtSetup').style.display = 'block';
  document.getElementById('mtGame').style.display = 'none';
  document.getElementById('mtResult').classList.remove('on');
}

function mtDiff(n, btn) {
  mtPairs = n;
  document.querySelectorAll('.diff-opt').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
}

function mtStart() {
  mtScore = 0; mtRounds = 0; mtLives = 3; mtTM = 0; mtTMiss = 0; mtStr = 0; mtBStr = 0;
  mtPool = shuffle([...W]);
  document.getElementById('mtSetup').style.display = 'none';
  document.getElementById('mtGame').style.display = 'flex';
  document.getElementById('mtResult').classList.remove('on');
  mtHUD(); mtRound();
}

function mtRound() {
  mtRounds++; mtMCnt = 0; mtSEng = null; mtSKor = null; mtBusy = false;
  document.getElementById('mtNext').classList.remove('on');
  if (mtPool.length < mtPairs) mtPool = shuffle([...W]);
  mtRW = mtPool.splice(0, mtPairs);
  mtHUD();

  const ec = document.getElementById('mtEng'), kc = document.getElementById('mtKor');
  ec.innerHTML = ''; kc.innerHTML = '';

  shuffle(mtRW).forEach((w, i) => {
    const c = document.createElement('div');
    c.className = 'm-card eng'; c.dataset.id = w.eng;
    c.innerHTML = `${w.eng}<span class="m-spk">🔊</span>`;
    c.style.cssText = 'opacity:0;transform:translateX(-14px);';
    c.addEventListener('click', () => mtClickE(w, c));
    ec.appendChild(c);
    setTimeout(() => { c.style.cssText = 'transition:all .22s;opacity:1;transform:none;'; }, i * 50 + 30);
  });

  shuffle(mtRW).forEach((w, i) => {
    const c = document.createElement('div');
    c.className = 'm-card kor'; c.dataset.id = w.eng;
    c.textContent = w.kor;
    c.style.cssText = 'opacity:0;transform:translateX(14px);';
    c.addEventListener('click', () => mtClickK(w, c));
    kc.appendChild(c);
    setTimeout(() => { c.style.cssText = 'transition:all .22s;opacity:1;transform:none;'; }, i * 50 + 30);
  });

  document.getElementById('mtProg').style.width = '0%';
}

function mtClickE(w, c) {
  if (mtBusy || c.classList.contains('matched')) return;
  speak(w.eng);
  if (mtSEng && mtSEng.c === c) { c.classList.remove('sel'); mtSEng = null; return; }
  if (mtSEng) mtSEng.c.classList.remove('sel');
  c.classList.add('sel'); mtSEng = { w, c };
  if (mtSKor) mtCheck();
}

function mtClickK(w, c) {
  if (mtBusy || c.classList.contains('matched')) return;
  if (mtSKor && mtSKor.c === c) { c.classList.remove('sel'); mtSKor = null; return; }
  if (mtSKor) mtSKor.c.classList.remove('sel');
  c.classList.add('sel'); mtSKor = { w, c };
  if (mtSEng) mtCheck();
}

function mtCheck() {
  mtBusy = true;
  const { w: ew, c: ec } = mtSEng, { w: kw, c: kc } = mtSKor;

  if (ew.eng === kw.eng) {
    mtStr++; if (mtStr > mtBStr) mtBStr = mtStr;
    const pts = 10 + Math.min(mtStr - 1, 9) * 3;
    mtScore += pts; mtTM++; mtMCnt++;
    ec.classList.remove('sel'); kc.classList.remove('sel');
    ec.classList.add('matched'); kc.classList.add('matched');
    fxAt(ec, `+${pts}`, '#22c55e'); sfx.ok();
    if (mtStr >= 3) { sfx.combo(); confetti(); }
    if (mtStr === 3) showBanner('🔥 3연속! 잘했어요!');
    if (mtStr === 5) showBanner('💥 5연속!! 대단해요!');
    mtSEng = null; mtSKor = null;
    document.getElementById('mtProg').style.width = (mtMCnt / mtPairs * 100) + '%';
    mtHUD();
    setTimeout(() => { mtBusy = false; if (mtMCnt === mtPairs) mtRoundDone(); }, 420);
  } else {
    mtStr = 0; mtTMiss++; mtLives = Math.max(0, mtLives - 1);
    ec.classList.remove('sel'); kc.classList.remove('sel');
    ec.classList.add('wrong-f'); kc.classList.add('wrong-f');
    fxAt(ec, '❌', '#ef4444'); sfx.no(); mtHUD();
    setTimeout(() => {
      ec.classList.remove('wrong-f'); kc.classList.remove('wrong-f');
      mtSEng = null; mtSKor = null; mtBusy = false;
      if (mtLives <= 0) mtEnd();
    }, 480);
  }
}

function mtRoundDone() {
  const b = 20 + mtRounds * 5;
  mtScore += b;
  showBanner(`🎉 라운드 ${mtRounds} 완료! +${b}`);
  sfx.clear(); confetti(); mtHUD();
  setTimeout(() => document.getElementById('mtNext').classList.add('on'), 600);
}

function mtHUD() {
  document.getElementById('mtScore').textContent = mtScore;
  document.getElementById('mtRound').textContent = mtRounds;
  document.getElementById('mtLives').textContent = '❤️'.repeat(mtLives) || '💔';
}

function mtEnd() {
  document.getElementById('mtGame').style.display = 'none';
  const acc = mtTM + mtTMiss > 0 ? Math.round(mtTM / (mtTM + mtTMiss) * 100) : 0;
  let em, tt;
  if (acc >= 90) { em = '🏆'; tt = '완벽해요!'; }
  else if (acc >= 70) { em = '🌟'; tt = '잘했어요!'; }
  else { em = '💪'; tt = '다시 도전!'; }

  document.getElementById('mtREmoji').textContent = em;
  document.getElementById('mtRTitle').textContent = tt;
  document.getElementById('mtRScore').textContent = mtScore + '점';
  document.getElementById('mtRRound').textContent = mtRounds;
  document.getElementById('mtRMatched').textContent = mtTM;
  document.getElementById('mtRMiss').textContent = mtTMiss;
  document.getElementById('mtRCombo').textContent = mtBStr;
  document.getElementById('mtResult').classList.add('on');
  confetti();
}
