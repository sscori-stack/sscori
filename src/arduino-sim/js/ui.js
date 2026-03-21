import { activities } from './activities.js';

let currentActivity = null;
let board = null;
let onActivityChange = null;

export function initUI(boardRef, activityChangeCb) {
  board = boardRef;
  onActivityChange = activityChangeCb;
  renderActivityNav();
}

function renderActivityNav() {
  const nav = document.getElementById('activityNav');
  nav.innerHTML = '';
  activities.forEach((act, i) => {
    const btn = document.createElement('button');
    btn.className = 'act-tab' + (i === 0 ? ' active' : '');
    btn.textContent = `${act.icon} ${act.title}`;
    btn.dataset.idx = i;
    btn.addEventListener('click', () => selectActivity(i));
    nav.appendChild(btn);
  });
}

export function selectActivity(idx) {
  currentActivity = activities[idx];

  document.querySelectorAll('.act-tab').forEach((b, i) => {
    b.classList.toggle('active', i === idx);
  });

  document.getElementById('actTitle').textContent = `${currentActivity.icon} ${currentActivity.title}`;
  document.getElementById('actDesc').textContent = currentActivity.description;

  const instrList = document.getElementById('instructionList');
  instrList.innerHTML = currentActivity.instructions
    .map(s => `<li>${s}</li>`).join('');

  const conceptsEl = document.getElementById('concepts');
  conceptsEl.innerHTML = currentActivity.concepts
    .map(c => `<span class="concept-tag">${c}</span>`).join('');

  renderCircuit(currentActivity);

  document.getElementById('editor').value = currentActivity.starterCode;
  updateLineNumbers();

  const hintContent = document.getElementById('hintContent');
  hintContent.style.display = 'none';
  hintContent.textContent = currentActivity.hint || '';

  const solutionPanel = document.getElementById('solutionPanel');
  solutionPanel.style.display = 'none';
  if (currentActivity.solutionCode) {
    document.getElementById('solutionCode').textContent = currentActivity.solutionCode;
  }

  document.getElementById('serialOutput').textContent = '';

  if (onActivityChange) onActivityChange(currentActivity);
}

function renderCircuit(activity) {
  const area = document.getElementById('componentArea');
  area.innerHTML = '';

  const leds = activity.leds || [];
  const isRGB = activity.isRGB;

  if (isRGB) {
    const rgbBox = document.createElement('div');
    rgbBox.className = 'rgb-led-box';
    rgbBox.innerHTML = `
      <div class="rgb-led-combined" id="rgbCombined">
        <div class="rgb-glow" id="rgbGlow"></div>
      </div>
      <div class="rgb-label">RGB LED</div>
      <div class="rgb-channels">
        ${leds.map(l => `
          <div class="rgb-channel">
            <div class="led-indicator" id="led-${l.pin}" data-pin="${l.pin}"
                 style="--led-color:${l.color}"></div>
            <span class="led-pin-label">${l.label}</span>
            <span class="led-value" id="led-val-${l.pin}">0</span>
          </div>
        `).join('')}
      </div>
    `;
    area.appendChild(rgbBox);
  } else {
    const grid = document.createElement('div');
    grid.className = 'led-grid';
    leds.forEach(l => {
      const cell = document.createElement('div');
      cell.className = 'led-cell';
      cell.innerHTML = `
        <div class="led-visual">
          <div class="led-glow" id="glow-${l.pin}" style="--led-color:${l.color}"></div>
          <div class="led-indicator" id="led-${l.pin}" data-pin="${l.pin}"
               style="--led-color:${l.color}"></div>
        </div>
        <div class="led-info">
          <span class="led-pin-label">${l.label}</span>
          <span class="led-value" id="led-val-${l.pin}">OFF</span>
        </div>
        <div class="led-wire" style="--wire-color:${l.color}">
          <span class="wire-label">핀 ${l.pin}</span>
        </div>
      `;
      grid.appendChild(cell);
    });
    area.appendChild(grid);
  }

  const connInfo = document.getElementById('connectionInfo');
  connInfo.innerHTML = '<strong>회로 연결:</strong> ' +
    leds.map(l => `핀${l.pin}→${l.label}`).join(' | ') +
    ' | GND→저항→LED';

  renderBoardPins(leds);
}

function renderBoardPins(leds) {
  const usedPins = new Set(leds.map(l => l.pin));
  const pinColorMap = {};
  leds.forEach(l => { pinColorMap[l.pin] = l.color; });

  document.querySelectorAll('.pin').forEach(pinEl => {
    const num = parseInt(pinEl.dataset.pin);
    pinEl.classList.toggle('connected', usedPins.has(num));
    if (usedPins.has(num)) {
      pinEl.style.setProperty('--pin-active-color', pinColorMap[num] || '#ffd700');
    } else {
      pinEl.style.removeProperty('--pin-active-color');
    }
  });
}

export function updateLedStates() {
  if (!currentActivity) return;
  const leds = currentActivity.leds || [];
  const isRGB = currentActivity.isRGB;

  leds.forEach(l => {
    const state = board.getLedState(l.pin);
    const el = document.getElementById(`led-${l.pin}`);
    const valEl = document.getElementById(`led-val-${l.pin}`);
    const glowEl = document.getElementById(`glow-${l.pin}`);

    if (el) {
      el.classList.toggle('on', state.on);
      el.style.setProperty('--brightness', state.brightness);
    }
    if (glowEl) {
      glowEl.style.opacity = state.brightness;
      glowEl.style.transform = `scale(${0.5 + state.brightness * 1.5})`;
    }
    if (valEl) {
      if (isRGB) {
        valEl.textContent = Math.round(state.brightness * 255);
      } else {
        valEl.textContent = state.on ? (state.brightness < 1 ? Math.round(state.brightness * 255) : 'ON') : 'OFF';
        valEl.className = 'led-value' + (state.on ? ' on' : '');
      }
    }
  });

  if (isRGB && leds.length === 3) {
    const r = board.getLedState(leds[0].pin).brightness;
    const g = board.getLedState(leds[1].pin).brightness;
    const b = board.getLedState(leds[2].pin).brightness;
    const glow = document.getElementById('rgbGlow');
    const combined = document.getElementById('rgbCombined');
    if (glow) {
      const color = `rgb(${Math.round(r*255)},${Math.round(g*255)},${Math.round(b*255)})`;
      glow.style.background = color;
      glow.style.opacity = Math.max(r, g, b);
      glow.style.boxShadow = `0 0 30px 15px ${color}`;
    }
    if (combined) {
      combined.style.setProperty('--rgb-r', r);
      combined.style.setProperty('--rgb-g', g);
      combined.style.setProperty('--rgb-b', b);
    }
  }

  updatePinStates(leds);
}

function updatePinStates(leds) {
  leds.forEach(l => {
    const pinEl = document.querySelector(`.pin[data-pin="${l.pin}"]`);
    if (pinEl) {
      const state = board.getLedState(l.pin);
      pinEl.classList.toggle('active', state.on);
    }
  });
}

export function updateLineNumbers() {
  const editor = document.getElementById('editor');
  const lineNums = document.getElementById('lineNumbers');
  const lines = editor.value.split('\n').length;
  lineNums.innerHTML = Array.from({ length: lines }, (_, i) => `<div>${i + 1}</div>`).join('');
}

export function appendSerial(text) {
  const output = document.getElementById('serialOutput');
  output.textContent += text;
  output.scrollTop = output.scrollHeight;
}

export function setRunning(isRunning) {
  document.getElementById('runBtn').disabled = isRunning;
  document.getElementById('stopBtn').disabled = !isRunning;
  document.getElementById('runBtn').classList.toggle('running', isRunning);
  document.getElementById('statusDot').className = 'status-dot ' + (isRunning ? 'running' : 'idle');
  document.getElementById('statusText').textContent = isRunning ? '실행 중...' : '준비';
}

export function getCurrentActivity() {
  return currentActivity;
}
