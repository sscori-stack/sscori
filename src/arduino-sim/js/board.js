const PWM_PINS = new Set([3, 5, 6, 9, 10, 11]);

export class ArduinoBoard {
  constructor() {
    this.pins = [];
    for (let i = 0; i < 20; i++) {
      this.pins.push({ mode: null, digital: 0, analog: 0, isPWM: PWM_PINS.has(i) });
    }
    this.running = false;
    this.speed = 1;
    this.startTime = 0;
    this.onPinChange = null;
    this.onSerialOut = null;
    this.components = [];
  }

  reset() {
    for (const p of this.pins) {
      p.mode = null; p.digital = 0; p.analog = 0;
    }
    this.running = false;
    if (this.onPinChange) this.onPinChange(-1);
  }

  pinMode(pin, mode) {
    if (pin < 0 || pin >= this.pins.length) return;
    this.pins[pin].mode = mode;
  }

  digitalWrite(pin, value) {
    if (pin < 0 || pin >= this.pins.length) return;
    const v = value ? 1 : 0;
    this.pins[pin].digital = v;
    this.pins[pin].analog = v ? 255 : 0;
    if (this.onPinChange) this.onPinChange(pin);
  }

  digitalRead(pin) {
    if (pin < 0 || pin >= this.pins.length) return 0;
    return this.pins[pin].digital;
  }

  analogWrite(pin, value) {
    if (pin < 0 || pin >= this.pins.length) return;
    const v = Math.max(0, Math.min(255, Math.round(value)));
    this.pins[pin].analog = v;
    this.pins[pin].digital = v > 0 ? 1 : 0;
    if (this.onPinChange) this.onPinChange(pin);
  }

  analogRead(pin) {
    return 0;
  }

  millis() {
    return Math.round((performance.now() - this.startTime) * this.speed);
  }

  async delay(ms) {
    const realMs = Math.max(1, ms / this.speed);
    return new Promise(resolve => setTimeout(resolve, realMs));
  }

  serialBegin() {}

  serialPrint(msg) {
    if (this.onSerialOut) this.onSerialOut(String(msg));
  }

  serialPrintln(msg) {
    if (this.onSerialOut) this.onSerialOut(String(msg) + '\n');
  }

  setComponents(comps) {
    this.components = comps;
  }

  getLedState(pin) {
    const p = this.pins[pin];
    if (!p) return { on: false, brightness: 0 };
    return { on: p.digital === 1, brightness: p.analog / 255 };
  }
}
