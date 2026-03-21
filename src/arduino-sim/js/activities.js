export const activities = [
  {
    id: 'blink',
    title: 'LED 깜빡이기',
    icon: '🔴',
    description: 'LED 하나를 1초 간격으로 켜고 끄는 기초 프로젝트입니다.',
    instructions: [
      '13번 핀에 빨간 LED가 연결되어 있습니다.',
      'setup()에서 13번 핀을 OUTPUT으로 설정하세요.',
      'loop()에서 digitalWrite로 LED를 켜고, delay 후 끄세요.',
    ],
    concepts: ['pinMode', 'digitalWrite', 'delay', 'HIGH/LOW'],
    leds: [
      { pin: 13, color: '#ef4444', label: 'LED1 (빨강)' }
    ],
    starterCode:
`// LED 깜빡이기 (Blink)
// 13번 핀의 LED를 1초 간격으로 깜빡입니다.

void setup() {
  pinMode(13, OUTPUT);
}

void loop() {
  // 여기에 코드를 작성하세요!
  // digitalWrite(핀번호, HIGH 또는 LOW)
  // delay(밀리초)

}`,
    solutionCode:
`void setup() {
  pinMode(13, OUTPUT);
}

void loop() {
  digitalWrite(13, HIGH);
  delay(1000);
  digitalWrite(13, LOW);
  delay(1000);
}`,
    hint: 'digitalWrite(13, HIGH)로 켜고, delay(1000)으로 1초 대기, digitalWrite(13, LOW)로 끄세요.',
  },

  {
    id: 'traffic',
    title: '신호등 만들기',
    icon: '🚦',
    description: '빨강, 노랑, 초록 LED 3개로 신호등을 만듭니다.',
    instructions: [
      '11번=빨강, 12번=노랑, 13번=초록 LED가 연결되어 있습니다.',
      '세 핀 모두 OUTPUT으로 설정하세요.',
      '빨강(3초) → 노랑(1초) → 초록(3초) 순서로 반복하세요.',
    ],
    concepts: ['여러 핀 제어', '순차 실행', '타이밍'],
    leds: [
      { pin: 11, color: '#ef4444', label: 'LED1 (빨강)' },
      { pin: 12, color: '#eab308', label: 'LED2 (노랑)' },
      { pin: 13, color: '#22c55e', label: 'LED3 (초록)' },
    ],
    starterCode:
`// 신호등 만들기
// 빨강(11), 노랑(12), 초록(13)

void setup() {
  pinMode(11, OUTPUT);
  pinMode(12, OUTPUT);
  pinMode(13, OUTPUT);
}

void loop() {
  // 빨간불: 11번 켜기, 나머지 끄기
  // 3초 대기
  // 노란불로 전환
  // 1초 대기
  // 초록불로 전환
  // 3초 대기

}`,
    solutionCode:
`void setup() {
  pinMode(11, OUTPUT);
  pinMode(12, OUTPUT);
  pinMode(13, OUTPUT);
}

void loop() {
  // 빨간불
  digitalWrite(11, HIGH);
  digitalWrite(12, LOW);
  digitalWrite(13, LOW);
  delay(3000);

  // 노란불
  digitalWrite(11, LOW);
  digitalWrite(12, HIGH);
  digitalWrite(13, LOW);
  delay(1000);

  // 초록불
  digitalWrite(11, LOW);
  digitalWrite(12, LOW);
  digitalWrite(13, HIGH);
  delay(3000);
}`,
    hint: '각 신호마다 해당 LED만 HIGH, 나머지는 LOW로 설정하세요.',
  },

  {
    id: 'fade',
    title: 'LED 밝기 조절 (Fade)',
    icon: '🌟',
    description: 'analogWrite를 사용해 LED 밝기를 서서히 변화시킵니다.',
    instructions: [
      '9번 핀(PWM)에 파란 LED가 연결되어 있습니다.',
      'analogWrite(핀, 0~255)로 밝기를 조절합니다.',
      'for문으로 0→255→0 반복하세요.',
    ],
    concepts: ['analogWrite', 'PWM', 'for문', '밝기 제어'],
    leds: [
      { pin: 9, color: '#3b82f6', label: 'LED1 (파랑, PWM)' }
    ],
    starterCode:
`// LED 밝기 조절 (Fade)
// 9번 핀(PWM)으로 밝기를 부드럽게 변화시킵니다.

void setup() {
  pinMode(9, OUTPUT);
}

void loop() {
  // for문으로 밝기를 0에서 255까지 올리기
  // analogWrite(9, 밝기값);
  // delay(10); 으로 부드럽게

  // for문으로 밝기를 255에서 0까지 내리기

}`,
    solutionCode:
`void setup() {
  pinMode(9, OUTPUT);
}

void loop() {
  for (int i = 0; i <= 255; i += 5) {
    analogWrite(9, i);
    delay(20);
  }
  for (int i = 255; i >= 0; i -= 5) {
    analogWrite(9, i);
    delay(20);
  }
}`,
    hint: 'for (int i = 0; i <= 255; i += 5) 로 밝기를 올리고, analogWrite(9, i)를 사용하세요.',
  },

  {
    id: 'pattern',
    title: 'LED 순차 패턴',
    icon: '✨',
    description: '5개의 LED를 순서대로 켜고 끄는 패턴을 만듭니다.',
    instructions: [
      '8~12번 핀에 5개 LED가 연결되어 있습니다.',
      'for문과 배열을 사용해 순서대로 켜세요.',
      '왕복 패턴(나이트 라이더)을 만들어보세요.',
    ],
    concepts: ['배열', 'for문', '순차 패턴', '다수 LED'],
    leds: [
      { pin: 8,  color: '#ef4444', label: 'LED1 (빨강)' },
      { pin: 9,  color: '#f97316', label: 'LED2 (주황)' },
      { pin: 10, color: '#eab308', label: 'LED3 (노랑)' },
      { pin: 11, color: '#22c55e', label: 'LED4 (초록)' },
      { pin: 12, color: '#3b82f6', label: 'LED5 (파랑)' },
    ],
    starterCode:
`// LED 순차 패턴 (Knight Rider)
// 8~12번 핀의 LED를 순서대로 켜고 끕니다.

int pins[] = {8, 9, 10, 11, 12};
int numLeds = 5;

void setup() {
  for (int i = 0; i < numLeds; i++) {
    pinMode(pins[i], OUTPUT);
  }
}

void loop() {
  // 왼쪽에서 오른쪽으로
  // for문으로 각 LED를 순서대로 켜고 끄기

  // 오른쪽에서 왼쪽으로

}`,
    solutionCode:
`int pins[] = {8, 9, 10, 11, 12};
int numLeds = 5;

void setup() {
  for (int i = 0; i < numLeds; i++) {
    pinMode(pins[i], OUTPUT);
  }
}

void loop() {
  for (int i = 0; i < numLeds; i++) {
    digitalWrite(pins[i], HIGH);
    delay(150);
    digitalWrite(pins[i], LOW);
  }
  for (int i = numLeds - 2; i > 0; i--) {
    digitalWrite(pins[i], HIGH);
    delay(150);
    digitalWrite(pins[i], LOW);
  }
}`,
    hint: '첫 번째 for문에서 i=0→4, 두 번째에서 i=3→1 로 왕복하세요.',
  },

  {
    id: 'rgb',
    title: 'RGB LED 무지개',
    icon: '🌈',
    description: 'RGB LED의 빨강/초록/파랑을 조합해 다양한 색을 만듭니다.',
    instructions: [
      '9번=빨강, 10번=초록, 11번=파랑 (모두 PWM 핀).',
      'analogWrite로 각 색의 밝기를 조절합니다.',
      '무지개 색상을 순서대로 표현해보세요.',
    ],
    concepts: ['RGB 색상 혼합', 'analogWrite', '색상 이론'],
    leds: [
      { pin: 9,  color: '#ef4444', label: 'R (빨강, PWM)' },
      { pin: 10, color: '#22c55e', label: 'G (초록, PWM)' },
      { pin: 11, color: '#3b82f6', label: 'B (파랑, PWM)' },
    ],
    isRGB: true,
    starterCode:
`// RGB LED 무지개
// 9=빨강, 10=초록, 11=파랑 (PWM)

int redPin = 9;
int greenPin = 10;
int bluePin = 11;

void setup() {
  pinMode(redPin, OUTPUT);
  pinMode(greenPin, OUTPUT);
  pinMode(bluePin, OUTPUT);
}

void loop() {
  // setColor 함수를 만들어 색상을 설정하세요
  // 빨강 → 노랑 → 초록 → 청록 → 파랑 → 보라 순서

  // 빨강 (255, 0, 0)
  analogWrite(redPin, 255);
  analogWrite(greenPin, 0);
  analogWrite(bluePin, 0);
  delay(1000);

  // 다음 색상들을 추가하세요!

}`,
    solutionCode:
`int redPin = 9;
int greenPin = 10;
int bluePin = 11;

void setup() {
  pinMode(redPin, OUTPUT);
  pinMode(greenPin, OUTPUT);
  pinMode(bluePin, OUTPUT);
}

void loop() {
  analogWrite(redPin, 255); analogWrite(greenPin, 0);   analogWrite(bluePin, 0);   delay(800);
  analogWrite(redPin, 255); analogWrite(greenPin, 165); analogWrite(bluePin, 0);   delay(800);
  analogWrite(redPin, 255); analogWrite(greenPin, 255); analogWrite(bluePin, 0);   delay(800);
  analogWrite(redPin, 0);   analogWrite(greenPin, 255); analogWrite(bluePin, 0);   delay(800);
  analogWrite(redPin, 0);   analogWrite(greenPin, 255); analogWrite(bluePin, 255); delay(800);
  analogWrite(redPin, 0);   analogWrite(greenPin, 0);   analogWrite(bluePin, 255); delay(800);
  analogWrite(redPin, 148); analogWrite(greenPin, 0);   analogWrite(bluePin, 211); delay(800);
}`,
    hint: 'analogWrite(핀, 0~255)로 각 색의 밝기를 조절하세요. 노랑 = 빨강255 + 초록255.',
  },

  {
    id: 'free',
    title: '자유 모드',
    icon: '🛠️',
    description: '원하는 LED 구성으로 자유롭게 코딩합니다.',
    instructions: [
      '8~13번 핀에 LED 6개가 연결되어 있습니다.',
      '자유롭게 코드를 작성해보세요!',
      'Serial.println()으로 시리얼 모니터에 출력할 수 있습니다.',
    ],
    concepts: ['자유 코딩', '창의적 패턴'],
    leds: [
      { pin: 8,  color: '#ef4444', label: 'LED1 (빨강)' },
      { pin: 9,  color: '#f97316', label: 'LED2 (주황)' },
      { pin: 10, color: '#eab308', label: 'LED3 (노랑)' },
      { pin: 11, color: '#22c55e', label: 'LED4 (초록)' },
      { pin: 12, color: '#3b82f6', label: 'LED5 (파랑)' },
      { pin: 13, color: '#a855f7', label: 'LED6 (보라)' },
    ],
    starterCode:
`// 자유 모드 - 마음대로 코딩하세요!
// 사용 가능한 LED: 8~13번 핀

void setup() {
  Serial.begin(9600);
  for (int i = 8; i <= 13; i++) {
    pinMode(i, OUTPUT);
  }
  Serial.println("준비 완료!");
}

void loop() {
  // 여기에 자유롭게 코드를 작성하세요!

}`,
    solutionCode: '',
    hint: '다양한 패턴을 시도해보세요: 랜덤, 대칭, 물결 등!',
  },
];
