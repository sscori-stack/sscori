import { W } from '../data/words.js';
import { speak, sfx } from '../audio.js';
import { shuffle, fxAt, confetti, showBanner } from '../utils.js';
import { goHome, setSqTimerID } from '../router.js';

let sqM = 'k2e', sqSec = 60, sqLeft = 0, sqScore = 0, sqCombo = 0, sqMaxC = 0;
let sqOK = 0, sqBad = 0, sqQN = 0, sqAns = false, sqBadW = [], sqPool2 = [];
let sqTimerID = null;

export function initSpeedQuiz() {
  document.querySelectorAll('[data-sq-mode]').forEach(btn => {
    btn.addEventListener('click', () => sqModeSet(btn.dataset.sqMode, btn));
  });
  document.querySelectorAll('[data-sq-time]').forEach(btn => {
    btn.addEventListener('click', () => sqTimeSet(parseInt(btn.dataset.sqTime), btn));
  });
  document.getElementById('sqStartBtn').addEventListener('click', sqStart);
  document.getElementById('sqResetBtn').addEventListener('click', sqShowSetup);
  document.getElementById('sqHomeBtn').addEventListener('click', goHome);
  document.getElementById('sqBack').addEventListener('click', goHome);
}

export function sqShowSetup() {
  document.getElementById('sqSetup').style.display = 'flex';
  document.getElementById('sqSetup').style.flexDirection = 'column';
  document.getElementById('sqGame').style.display = 'none';
  document.getElementById('sqResult').classList.remove('on');
}

function sqModeSet(m, btn) {
  sqM = m;
  document.getElementById('sqModeRow').querySelectorAll('.sq-opt').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
}

function sqTimeSet(t, btn) {
  sqSec = t;
  document.getElementById('sqTimeRow').querySelectorAll('.sq-opt').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
}

function sqStart() {
  sqScore = 0; sqCombo = 0; sqMaxC = 0; sqOK = 0; sqBad = 0; sqQN = 0; sqAns = false;
  sqBadW = []; sqLeft = sqSec;
  sqPool2 = shuffle([...W]);

  document.getElementById('sqSetup').style.display = 'none';
  document.getElementById('sqGame').style.display = 'flex';
  document.getElementById('sqGame').style.flexDirection = 'column';
  document.getElementById('sqResult').classList.remove('on');
  document.getElementById('sqTimer').textContent = sqLeft;
  document.getElementById('sqTimerFill').style.width = '100%';
  document.getElementById('sqTimerBox').classList.remove('danger');
  sqHUD(); sqQ();

  sqTimerID = setInterval(() => {
    sqLeft--;
    document.getElementById('sqTimer').textContent = sqLeft;
    document.getElementById('sqTimerFill').style.width = (sqLeft / sqSec * 100) + '%';
    if (sqLeft <= 10) { document.getElementById('sqTimerBox').classList.add('danger'); sfx.tick(); }
    if (sqLeft <= 0) { clearInterval(sqTimerID); sqTimerID = null; setSqTimerID(null); sqEnd(); }
  }, 1000);
  setSqTimerID(sqTimerID);
}

function sqHUD() {
  document.getElementById('sqScore').textContent = sqScore;
  document.getElementById('sqComboDisp').textContent = sqCombo;
}

function sqQ() {
  sqAns = false;
  if (sqPool2.length < 4) sqPool2 = shuffle([...W]);
  const cor = sqPool2.pop();
  const opts = shuffle([cor, ...shuffle(W.filter(w => w.eng !== cor.eng)).slice(0, 3)]);
  sqQN++;

  document.getElementById('sqQLabel').textContent = sqM === 'k2e' ? '🇰🇷 뜻 → 🇺🇸 영단어' : '🇺🇸 영단어 → 🇰🇷 뜻';
  document.getElementById('sqQNum').textContent = `문제 ${sqQN}`;

  const stem = sqM === 'k2e' ? cor.kor : cor.eng;
  const el = document.getElementById('sqStem');
  el.textContent = stem;
  el.className = 'q-stem' + (stem.length > 8 ? ' sm' : '');
  if (sqM === 'e2k') speak(cor.eng);

  const g = document.getElementById('sqGrid');
  g.innerHTML = '';
  opts.forEach(opt => {
    const b = document.createElement('button');
    b.className = 'q-btn';
    b.textContent = sqM === 'k2e' ? opt.eng : opt.kor;
    b.addEventListener('click', () => sqAns2(opt, cor, b));
    g.appendChild(b);
  });
}

function sqAns2(opt, cor, btn) {
  if (sqAns) return;
  sqAns = true;
  const ok = opt.eng === cor.eng;

  document.querySelectorAll('.q-btn').forEach(b => {
    b.disabled = true;
    if (sqM === 'k2e' ? b.textContent === cor.eng : b.textContent === cor.kor) b.classList.add('correct');
  });

  if (ok) {
    sqOK++; sqCombo++;
    if (sqCombo > sqMaxC) sqMaxC = sqCombo;
    const pts = 10 + Math.min(sqCombo - 1, 9) * 2;
    sqScore += pts; sfx.ok();
    fxAt(btn, `+${pts}`, '#22c55e');
    const ct = document.getElementById('sqCTag');
    if (sqCombo >= 3) { ct.textContent = `🔥 ${sqCombo}연속!`; ct.classList.add('on'); sfx.combo(); }
    if (sqCombo === 3) showBanner('🔥 3연속!');
    if (sqCombo === 5) { showBanner('💥 5연속!!'); confetti(); }
    setTimeout(sqQ, 560);
  } else {
    sqBad++; sqCombo = 0;
    btn.classList.add('wrong'); sfx.no();
    sqBadW.push(cor);
    document.getElementById('sqCTag').classList.remove('on');
    fxAt(btn, '❌', '#ef4444');
    setTimeout(sqQ, 840);
  }
  sqHUD();
}

function sqEnd() {
  sfx.over(); confetti();
  document.getElementById('sqGame').style.display = 'none';
  const tot = sqOK + sqBad, acc = tot > 0 ? Math.round(sqOK / tot * 100) : 0;
  let em, tt;
  if (acc >= 90) { em = '🏆'; tt = '완벽해요!'; }
  else if (acc >= 70) { em = '🌟'; tt = '잘했어요!'; }
  else { em = '💪'; tt = '다시 도전!'; }

  document.getElementById('sqREmoji').textContent = em;
  document.getElementById('sqRTitle').textContent = tt;
  document.getElementById('sqRScore').textContent = sqScore + '점';
  document.getElementById('sqRStars').textContent = acc >= 90 ? '⭐⭐⭐' : acc >= 70 ? '⭐⭐' : '⭐';
  document.getElementById('sqRC').textContent = sqOK;
  document.getElementById('sqRW').textContent = sqBad;
  document.getElementById('sqRCombo').textContent = sqMaxC;
  document.getElementById('sqRAcc').textContent = acc + '%';

  const uniq = [...new Map(sqBadW.map(w => [w.eng, w])).values()];
  const dl = document.getElementById('sqRList');
  dl.innerHTML = !uniq.length
    ? '<div style="text-align:center;color:var(--grn);padding:8px;font-size:.85rem">🎉 오답 없음!</div>'
    : '<div style="font-size:.7rem;color:var(--red);margin-bottom:6px;font-weight:700">❌ 틀린 단어 (' + uniq.length + '개)</div>'
      + uniq.map(w => `<div class="dont-row"><b>${w.eng}</b><span style="color:var(--muted)">${w.kor}</span></div>`).join('');

  document.getElementById('sqResult').classList.add('on');
}
