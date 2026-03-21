import { ArduinoBoard } from './board.js';
import { Interpreter } from './interpreter.js';
import {
  initUI, selectActivity, updateLedStates, updateLineNumbers,
  appendSerial, setRunning, getCurrentActivity
} from './ui.js';

const board = new ArduinoBoard();
const interpreter = new Interpreter(board);
let animFrame = null;

board.onPinChange = () => updateLedStates();
board.onSerialOut = (msg) => appendSerial(msg);
interpreter.onFinish = () => { setRunning(false); stopAnimLoop(); };

function startAnimLoop() {
  function tick() {
    updateLedStates();
    animFrame = requestAnimationFrame(tick);
  }
  animFrame = requestAnimationFrame(tick);
}

function stopAnimLoop() {
  if (animFrame) { cancelAnimationFrame(animFrame); animFrame = null; }
}

function runCode() {
  const code = document.getElementById('editor').value;
  if (!code.trim()) return;
  board.reset();
  updateLedStates();
  document.getElementById('serialOutput').textContent = '';
  setRunning(true);
  startAnimLoop();
  interpreter.run(code);
}

function stopCode() {
  interpreter.stop();
  setRunning(false);
  stopAnimLoop();
}

function resetCode() {
  interpreter.stop();
  board.reset();
  setRunning(false);
  stopAnimLoop();
  updateLedStates();
  document.getElementById('serialOutput').textContent = '';
}

initUI(board, () => resetCode());
selectActivity(0);

document.getElementById('runBtn').addEventListener('click', runCode);
document.getElementById('stopBtn').addEventListener('click', stopCode);
document.getElementById('resetBtn').addEventListener('click', resetCode);

document.getElementById('clearSerial').addEventListener('click', () => {
  document.getElementById('serialOutput').textContent = '';
});

const editor = document.getElementById('editor');
editor.addEventListener('input', updateLineNumbers);
editor.addEventListener('scroll', () => {
  document.getElementById('lineNumbers').scrollTop = editor.scrollTop;
});
editor.addEventListener('keydown', e => {
  if (e.key === 'Tab') {
    e.preventDefault();
    const start = editor.selectionStart;
    const end = editor.selectionEnd;
    editor.value = editor.value.substring(0, start) + '  ' + editor.value.substring(end);
    editor.selectionStart = editor.selectionEnd = start + 2;
    updateLineNumbers();
  }
});

document.getElementById('speedSelect').addEventListener('change', e => {
  board.speed = parseFloat(e.target.value);
});

document.getElementById('hintBtn').addEventListener('click', () => {
  const el = document.getElementById('hintContent');
  el.style.display = el.style.display === 'none' ? 'block' : 'none';
});

document.getElementById('solutionBtn').addEventListener('click', () => {
  const el = document.getElementById('solutionPanel');
  el.style.display = el.style.display === 'none' ? 'block' : 'none';
});

document.getElementById('loadSolution').addEventListener('click', () => {
  const act = getCurrentActivity();
  if (act && act.solutionCode) {
    editor.value = act.solutionCode;
    updateLineNumbers();
  }
});
