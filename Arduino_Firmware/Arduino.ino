#include <SoftwareSerial.h>

SoftwareSerial BT(8, 9);

const int IN1 = 10;
const int IN2 = 11;
const int IN3 = 5;
const int IN4 = 6;

const int S1 = 2;
const int S2 = 3;
const int S3 = 4;
const int S4 = 7;

const int trigPin = A0;
const int echoPin = A1;
const int buzzerPin = A2;
const int engelMesafe = 15;

char mod = 'M';
char sonKomut = 'S';
int hiz = 120;

float Kp = 100.0;
float Ki = 0.0;
float Kd = 25.0;

float error = 0;
float lastError = 0;
float integral = 0;
float derivative = 0;
float correction = 0;

float mesafe = 999.0;

unsigned long sonOlcumZamani = 0;
const unsigned long olcumAralik = 60;

unsigned long sonMesafeGondermeZamani = 0;
const unsigned long mesafeGondermeAralik = 200;

void setup() {
  pinMode(IN1, OUTPUT);
  pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT);
  pinMode(IN4, OUTPUT);

  pinMode(S1, INPUT);
  pinMode(S2, INPUT);
  pinMode(S3, INPUT);
  pinMode(S4, INPUT);

  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);
  pinMode(buzzerPin, OUTPUT);

  digitalWrite(buzzerPin, LOW);

  BT.begin(9600);
  dur();
}

void loop() {
  guncelleMesafe();
  gonderMesafe();
  buzzerKontrol();

  if (engelVar() && (mod == 'A' || sonKomut == 'F' || sonKomut == 'I' || sonKomut == 'G')) {
    dur();
  }

  if (BT.available()) {
    char s = BT.read();

    if (s >= '0' && s <= '9') {
      hiz = map(s - '0', 0, 9, 90, 180);
    }

    if (s == 'A') {
      mod = 'A';
    }
    else if (s == 'M') {
      mod = 'M';
      dur();
    }

    if (mod == 'M') {
      if (s == 'F') {
        if (!engelVar()) ileri();
        else dur();
      }
      else if (s == 'B') geri();
      else if (s == 'R') sagaDon();
      else if (s == 'L') solaDon();
      else if (s == 'I') {
        if (!engelVar()) ileriSag();
        else dur();
      }
      else if (s == 'G') {
        if (!engelVar()) ileriSol();
        else dur();
      }
      else if (s == 'S') dur();
    }
  }

  if (mod == 'A') {
    if (!engelVar()) {
      hatIzleme();
    }
    else {
      dur();
    }
  }
}

void guncelleMesafe() {
  unsigned long simdi = millis();

  if (simdi - sonOlcumZamani >= olcumAralik) {
    sonOlcumZamani = simdi;
    mesafe = mesafeOku();
  }
}

float mesafeOku() {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);

  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  long sure = pulseIn(echoPin, HIGH, 25000);

  if (sure == 0) {
    return 999.0;
  }

  float uzaklik = sure * 0.0343 / 2.0;
  return uzaklik;
}

void gonderMesafe() {
  unsigned long simdi = millis();

  if (simdi - sonMesafeGondermeZamani >= mesafeGondermeAralik) {
    sonMesafeGondermeZamani = simdi;
    BT.print("D:");
    BT.println(mesafe, 2); 
  }
}

bool engelVar() {
  return mesafe > 0.0 && mesafe <= engelMesafe;
}

void buzzerKontrol() {
  if (engelVar()) {
    digitalWrite(buzzerPin, HIGH);
  }
  else {
    digitalWrite(buzzerPin, LOW);
  }
}

void hatIzleme() {
  int sen1 = digitalRead(S1);
  int sen2 = digitalRead(S2);
  int sen3 = digitalRead(S3);
  int sen4 = digitalRead(S4);

  int b1 = sen1;
  int b2 = sen2;
  int b3 = sen3;
  int b4 = sen4;

  int toplam = b1 + b2 + b3 + b4;

  if (toplam == 0) {
    dur();
    error = 0;
    integral = 0;
    return;
  }

  if (toplam == 4) {
    motorSur(hiz, hiz);
    return;
  }

  error = ((b1 * -3.0) + (b2 * -1.0) + (b3 * 1.0) + (b4 * 3.0)) / toplam;

  integral = 0;
  derivative = error - lastError;

  correction = (Kp * error) + (Ki * integral) + (Kd * derivative);

  lastError = error;

  int solHiz = hiz + correction;
  int sagHiz = hiz - correction;

  solHiz = constrain(solHiz, 0, 210);
  sagHiz = constrain(sagHiz, 0, 210);

  motorSur(solHiz, sagHiz);
}

void motorSur(int solHiz, int sagHiz) {
  analogWrite(IN1, sagHiz);
  digitalWrite(IN2, LOW);

  analogWrite(IN3, solHiz);
  digitalWrite(IN4, LOW);
}

void ileri() {
  sonKomut = 'F';

  analogWrite(IN1, hiz);
  digitalWrite(IN2, LOW);

  analogWrite(IN3, hiz);
  digitalWrite(IN4, LOW);
}

void geri() {
  sonKomut = 'B';

  digitalWrite(IN1, LOW);
  analogWrite(IN2, hiz);

  digitalWrite(IN3, LOW);
  analogWrite(IN4, hiz);
}

void sagaDon() {
  sonKomut = 'R';

  analogWrite(IN1, hiz);
  digitalWrite(IN2, LOW);

  digitalWrite(IN3, LOW);
  analogWrite(IN4, hiz);
}

void solaDon() {
  sonKomut = 'L';

  digitalWrite(IN1, LOW);
  analogWrite(IN2, hiz);

  analogWrite(IN3, hiz);
  digitalWrite(IN4, LOW);
}

void ileriSag() {
  sonKomut = 'I';

  int fastSpeed = constrain(hiz + 40, 0, 255);
  int slowSpeed = (hiz * 30) / 100;

  analogWrite(IN1, slowSpeed);
  digitalWrite(IN2, LOW);

  analogWrite(IN3, fastSpeed);
  digitalWrite(IN4, LOW);
}

void ileriSol() {
  sonKomut = 'G';

  int fastSpeed = constrain(hiz + 40, 0, 255);
  int slowSpeed = (hiz * 30) / 100;

  analogWrite(IN1, fastSpeed);
  digitalWrite(IN2, LOW);

  analogWrite(IN3, slowSpeed);
  digitalWrite(IN4, LOW);
}

void dur() {
  sonKomut = 'S';

  digitalWrite(IN1, LOW);
  digitalWrite(IN2, LOW);

  digitalWrite(IN3, LOW);
  digitalWrite(IN4, LOW);
}