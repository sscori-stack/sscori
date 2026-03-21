export class Interpreter {
  constructor(board) {
    this.board = board;
    this.running = false;
    this.onError = null;
    this.onFinish = null;
  }

  transpile(code) {
    let js = code;

    // Remove #include lines
    js = js.replace(/#include\s+.*$/gm, '');

    // Replace #define
    js = js.replace(/#define\s+(\w+)\s+(.+)$/gm, 'const $1 = $2;');

    // Remove single-line comments temporarily, preserving line count
    const strings = [];
    js = js.replace(/(["'])(?:(?=(\\?))\2.)*?\1/g, m => {
      strings.push(m);
      return `__STR${strings.length - 1}__`;
    });

    // Remove comments
    js = js.replace(/\/\/.*$/gm, '');
    js = js.replace(/\/\*[\s\S]*?\*\//g, '');

    // Replace type declarations
    js = js.replace(/\b(void)\s+(\w+)\s*\(/g, (_, _t, name) => {
      if (name === 'setup') return 'async function __setup(';
      if (name === 'loop') return 'async function __loop(';
      return `async function ${name}(`;
    });
    // C-style array declarations: int pins[] = {1,2,3}; → let pins = [1,2,3];
    js = js.replace(
      /\b(int|long|unsigned\s+long|float|double|byte|boolean|bool|char|String|uint8_t|uint16_t|uint32_t)\s+(\w+)\s*\[\s*\d*\s*\]\s*=\s*\{([^}]*)\}/g,
      'let $2 = [$3]'
    );

    js = js.replace(/\b(int|long|unsigned\s+long|float|double|byte|boolean|bool|char|String|uint8_t|uint16_t|uint32_t)\s+/g, 'let ');
    js = js.replace(/\bconst\s+let\s+/g, 'const ');

    // Replace constants
    js = js.replace(/\bHIGH\b/g, '1');
    js = js.replace(/\bLOW\b/g, '0');
    js = js.replace(/\bOUTPUT\b/g, '"OUTPUT"');
    js = js.replace(/\bINPUT\b/g, '"INPUT"');
    js = js.replace(/\bINPUT_PULLUP\b/g, '"INPUT_PULLUP"');
    js = js.replace(/\bLED_BUILTIN\b/g, '13');

    // Replace Arduino functions with board calls
    js = js.replace(/\bpinMode\s*\(/g, 'board.pinMode(');
    js = js.replace(/\bdigitalWrite\s*\(/g, 'board.digitalWrite(');
    js = js.replace(/\bdigitalRead\s*\(/g, 'board.digitalRead(');
    js = js.replace(/\banalogWrite\s*\(/g, 'board.analogWrite(');
    js = js.replace(/\banalogRead\s*\(/g, 'board.analogRead(');
    js = js.replace(/\bdelay\s*\(/g, 'await board.delay(');
    js = js.replace(/\bmillis\s*\(/g, 'board.millis(');
    js = js.replace(/\bSerial\.begin\s*\(/g, 'board.serialBegin(');
    js = js.replace(/\bSerial\.println\s*\(/g, 'board.serialPrintln(');
    js = js.replace(/\bSerial\.print\s*\(/g, 'board.serialPrint(');

    // Add yield points in for/while loops to prevent browser hang
    js = js.replace(
      /\b(for\s*\([^)]*\)\s*\{)/g,
      '$1 if(!__run()) return; '
    );
    js = js.replace(
      /\b(while\s*\([^)]*\)\s*\{)/g,
      '$1 if(!__run()) return; '
    );

    // Restore strings
    js = js.replace(/__STR(\d+)__/g, (_, i) => strings[i]);

    return js;
  }

  async run(code) {
    this.running = true;
    this.board.running = true;
    this.board.startTime = performance.now();

    const js = this.transpile(code);

    const wrapper = `
      ${js}

      if (typeof __setup === 'function') await __setup();
      if (typeof __loop === 'function') {
        while (__run()) {
          await __loop();
          await new Promise(r => setTimeout(r, 0));
        }
      }
    `;

    try {
      const AsyncFunction = Object.getPrototypeOf(async function(){}).constructor;
      const fn = new AsyncFunction('board', '__run', wrapper);
      await fn(this.board, () => this.running);
    } catch (e) {
      const msg = this.formatError(e);
      if (this.onError) this.onError(msg);
      this.board.serialPrint('\n[오류] ' + msg + '\n');
    }

    this.running = false;
    this.board.running = false;
    if (this.onFinish) this.onFinish();
  }

  stop() {
    this.running = false;
    this.board.running = false;
  }

  formatError(e) {
    const msg = e.message || String(e);
    if (msg.includes('is not defined')) {
      const varName = msg.match(/(\w+) is not defined/);
      return varName ? `'${varName[1]}'이(가) 정의되지 않았습니다.` : msg;
    }
    if (msg.includes('Unexpected token')) return '문법 오류: 코드를 확인해주세요.';
    if (msg.includes('is not a function')) return '함수 호출 오류: 함수명을 확인해주세요.';
    return msg;
  }
}
