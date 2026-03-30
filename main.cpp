#include <Arduino.h>
#include <M5Core2.h>
#include <Adafruit_seesaw.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define SEESAW_ADDR          0x50

// Define button pins on the seesaw board
#define BUTTON_X 6
#define BUTTON_Y 2
#define BUTTON_A 5
#define BUTTON_B 1
#define BUTTON_START 16
#define BUTTON_SELECT 0

#define MAX_SEQUENCE 20
#define SABOTEUR_WIN_POINTS 50  

BLECharacteristic *pCharacteristic;
bool deviceConnected = false;

// UUIDs (you can keep these)
#define SERVICE_UUID        "12345678-1234-1234-1234-123456789abc"
#define CHARACTERISTIC_UUID "abcd1234-5678-1234-5678-123456789abc"


double points = 0;

int bombCost = 5;
int blindCost = 15;

bool prevY = HIGH;
bool prevA = HIGH;

int screen = 0;


int sequence[MAX_SEQUENCE];
int seqLength = 1;
int playerIndex = 0;

bool showingSequence = true;
int showIndex = 0;
unsigned long lastStepTime = 0;
int showDelay = 500; 

bool isFrozen = false;
unsigned long freezeStartTime = 0;
const int freezeDuration = 10000; // 10 seconds

bool waitingScreenDrawn = false;
bool justConnected = false;  // Flag to indicate a new connection for waiting screen logic



uint32_t button_mask = (1UL << BUTTON_X) | (1UL << BUTTON_Y) |
                       (1UL << BUTTON_A) | (1UL << BUTTON_B) |
                       (1UL << BUTTON_START) | (1UL << BUTTON_SELECT);
Adafruit_seesaw ss;

void buyScreen();
void gameScreen();
void footer();
void pointsBar();
void flashButton(int button);
void drawButtons();
void resetGame();
void startFreeze();
void updateFreeze();
void drawFreezeOverlay();
void waitingScreen();

class MyServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    justConnected = true;  // ← flag only, no LCD call here
    Serial.println("Phone connected!");
  }

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    waitingScreenDrawn = false;  
    Serial.println("Phone disconnected!");
  }
};
class MyCharCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pChar) {
    std::string value = pChar->getValue();
    if (value.length() > 0) {
      Serial.print("Received: ");
      Serial.println(value.c_str());

      if (value == "FREEZE") {
        startFreeze();
      } else if (value == "UNFREEZE") {
        isFrozen = false;
        M5.Lcd.fillScreen(BLACK);
        Serial.println("Unfrozen by phone!");
      } else if (value == "WIN") {
        // Player won — stop the game on the saboteur side
        screen = 0;          // kick back to buy screen
        points = 0;          // reset saboteur points
        M5.Lcd.fillScreen(BLACK);
        M5.Lcd.setTextSize(3);
        M5.Lcd.setTextColor(RED);
        M5.Lcd.setCursor(50, 100);
        M5.Lcd.print("YOU LOST!");
        delay(3000);
        M5.Lcd.fillScreen(BLACK);
        Serial.println("Player won!");
      }
    }
  }
};
void setup() {
  // put your setup code here, to run once:
  M5.begin();
  points = 0;
  screen = 0;
  bombCost = 10;
  blindCost = 20;

  BLEDevice::init("Fruit Assassin");

  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_NOTIFY |
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_WRITE
  );
  pCharacteristic->setCallbacks(new MyCharCallbacks()); // ← add this line
  pCharacteristic->addDescriptor(new BLE2902());

  pService->start();

  // Start advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->start();

  Serial.println("BLE ready, waiting for phone...");

  pCharacteristic->setValue("READY");

  if (!ss.begin(SEESAW_ADDR)) {
    Serial.println("ERROR: Seesaw not found!");
    while(1);
  }
  Serial.println("Seesaw started");
  ss.pinModeBulk(button_mask, INPUT_PULLUP);

  randomSeed(millis());

  for(int i = 0; i < MAX_SEQUENCE; i++) {
    int buttons[4] = {BUTTON_X, BUTTON_Y, BUTTON_A, BUTTON_B};
    sequence[i] = buttons[random(0, 4)];
  }

}

void loop() {
  M5.update();
  // if(M5.BtnA.isPressed()) {
  //   startFreeze();
  // }

  if (points >= SABOTEUR_WIN_POINTS) {
    // Saboteur wins!
    Serial.println("Saboteur wins!");
    pCharacteristic->setValue("SABOTEUR_WIN");
    pCharacteristic->notify();
    points = 0;
    M5.Lcd.fillScreen(BLACK);
    M5.Lcd.setTextSize(3);
    M5.Lcd.setTextColor(GREEN);
    M5.Lcd.setCursor(30, 100);
    M5.Lcd.print("YOU WIN!");
    delay(3000);
    
  }

  updateFreeze();

  if (justConnected) {
    justConnected = false;
    waitingScreenDrawn = false;
    M5.Lcd.fillScreen(BLACK);
  }

  if (!deviceConnected) {
    waitingScreen();
    delay(50);
    return;  // ← skip everything else until phone connects
  }


  bool startPressed = ss.digitalRead(BUTTON_START) == LOW;
  bool selectPressed = ss.digitalRead(BUTTON_SELECT) == LOW;

  if (startPressed && screen != 0) {
    screen = 0;
    Serial.println("Switching to buy screen");
    M5.Lcd.fillScreen(BLACK);

  } else if (selectPressed && screen != 1) {
    resetGame();
    screen = 1;
    Serial.println("Switching to game screen");
    M5.Lcd.fillScreen(BLACK);

  }

  if (screen == 0) {
    buyScreen();
  } else if (screen == 1) {
    gameScreen();
  }

  delay(50);


}

void buyScreen() {

  if (isFrozen) {
  drawFreezeOverlay();
  footer();
  return;
}

  // ===== TITLE =====
  M5.Lcd.setTextSize(3);
  M5.Lcd.setTextColor(RED);
  M5.Lcd.setCursor(40, 5);
  M5.Lcd.print("SABOTAGE");

  // ===== POINTS BAR =====
  pointsBar();

  // ===== BOMB CARD =====
  int bombY = 80;
  uint16_t bombColor = (points >= bombCost) ? RED : DARKGREY;

  M5.Lcd.drawRect(10, bombY, 300, 40, bombColor);
  M5.Lcd.setTextColor(bombColor);
  M5.Lcd.setCursor(20, bombY + 10);
  M5.Lcd.print("[Y] BOMB");

  M5.Lcd.setTextColor(WHITE);
  M5.Lcd.setCursor(180, bombY + 10);
  M5.Lcd.print(bombCost);

  // ===== BLIND CARD =====
  int blindY = 130;
  uint16_t blindColor = (points >= blindCost) ? BLUE : DARKGREY;

  M5.Lcd.drawRect(10, blindY, 300, 40, blindColor);
  M5.Lcd.setTextColor(blindColor);
  M5.Lcd.setCursor(20, blindY + 10);
  M5.Lcd.print("[A] BLIND");

  M5.Lcd.setTextColor(WHITE);
  M5.Lcd.setCursor(180, blindY + 10);
  M5.Lcd.print(blindCost);

  // ===== PASSIVE POINT GAIN =====
  if (!isFrozen) {
    points += 0.04;
  }

  // ===== INPUT HANDLING =====
  bool currY = ss.digitalRead(BUTTON_Y);
  bool currA = ss.digitalRead(BUTTON_A);

  // Trigger ONLY on press (HIGH -> LOW)
  // In buyScreen(), replace the flash-and-do-nothing blocks:

if (!isFrozen && currY == LOW && prevY == HIGH && points >= bombCost) {
  points -= bombCost;
  if (deviceConnected) {
    pCharacteristic->setValue("BOMB");   // Flutter parses this
    pCharacteristic->notify();
  }
  M5.Lcd.fillScreen(RED);
  delay(80);
  M5.Lcd.fillScreen(BLACK);
}

if (!isFrozen && currA == LOW && prevA == HIGH && points >= blindCost) {
  points -= blindCost;
  if (deviceConnected) {
    pCharacteristic->setValue("BLIND");  // Flutter parses this
    pCharacteristic->notify();
  }
  M5.Lcd.fillScreen(BLUE);
  delay(80);
  M5.Lcd.fillScreen(BLACK);
}

  footer();

  // Update previous states
  prevY = currY;
  prevA = currA;
}

void gameScreen() {

  if (isFrozen) {
  footer();
  drawFreezeOverlay();
  return;
}

  pointsBar();
  drawButtons();
  static bool buttonHeld = false;

  unsigned long now = millis();

  // ===== SHOW SEQUENCE =====
  if (showingSequence) {
    if (now - lastStepTime > showDelay) {
      if (showIndex < seqLength) {
        flashButton(sequence[showIndex]);
        showIndex++;
      } else {
        // Done showing
        showingSequence = false;
        showIndex = 0;
        M5.Lcd.fillScreen(BLACK);
      }
      lastStepTime = now;
    }
    return;
  }

  // ===== PLAYER INPUT =====
  int buttons[4] = {BUTTON_X, BUTTON_Y, BUTTON_A, BUTTON_B};

  bool anyPressed = false;

for (int i = 0; i < 4; i++) {
  if (ss.digitalRead(buttons[i]) == LOW) {
    anyPressed = true;

    if (!buttonHeld) {
      buttonHeld = true;

      flashButton(buttons[i]);

      if (buttons[i] == sequence[playerIndex]) {
        playerIndex++;

        if (playerIndex >= seqLength) {
          points += seqLength * 2;
          seqLength++;
          playerIndex = 0;
          showingSequence = true;
          lastStepTime = millis(); // ← add this
          M5.Lcd.fillScreen(GREEN);
          delay(100);
          M5.Lcd.fillScreen(BLACK); // ← add this too
        }
      } else {
        M5.Lcd.fillScreen(RED);

        seqLength = 1;
        playerIndex = 0;
        points -= 5;
        showingSequence = true;
      }
    }
    break;
  }
}

if (!anyPressed) {
  buttonHeld = false;
}

  footer();
}


void footer() {
  int footerY = 200;

  // Background bar
  M5.Lcd.fillRect(0, footerY, 320, 40, DARKGREY);

  M5.Lcd.setTextSize(1);
  M5.Lcd.setTextColor(WHITE);

  // START hint (left side)
  M5.Lcd.setCursor(10, footerY + 12);
  M5.Lcd.print("START: Shop");

  // SELECT hint (right side)
  M5.Lcd.setCursor(225, footerY + 12);
  M5.Lcd.print("SELECT: Game");
}

void resetGame() {
  seqLength = 1;
  playerIndex = 0;
  showingSequence = true;
  showIndex = 0;
  lastStepTime = millis();

  // regenerate sequence for extra evil randomness
  int buttons[4] = {BUTTON_X, BUTTON_Y, BUTTON_A, BUTTON_B};
  for (int i = 0; i < MAX_SEQUENCE; i++) {
    sequence[i] = buttons[random(0, 4)];
  }
}

void pointsBar(){
  int pointsInt = (int) points;
  M5.Lcd.fillRect(0, 35, 320, 30, DARKGREY);
  M5.Lcd.setTextSize(2);
  M5.Lcd.setTextColor(WHITE);
  M5.Lcd.setCursor(10, 42);
  M5.Lcd.print("Points: ");
  M5.Lcd.setTextColor(GREEN);
  M5.Lcd.print(pointsInt);
}

void flashButton(int button) {
  int size = 50;
  int centerX = 160;

  int x, y;

  switch(button) {
    case BUTTON_X: x = centerX - size/2; y = 70; break;
    case BUTTON_Y: x = centerX - size - 25; y = 115; break;
    case BUTTON_A: x = centerX + 25; y = 115; break;
    case BUTTON_B: x = centerX - size/2; y = 145; break;
  }

  M5.Lcd.fillRoundRect(x, y, size, size, 8, WHITE);
  delay(100);

  drawButtons();
}

void drawButtons() {
  int size = 50;
  int centerX = 160;

  int xX = centerX - size/2;
  int yX = 70;

  int xY = centerX - size - 25;
  int yY = 115;

  int xA = centerX + 25;
  int yA = 115;

  int xB = centerX - size/2;
  int yB = 145;  

  M5.Lcd.fillRoundRect(xX, yX, size, size, 8, YELLOW);
  M5.Lcd.fillRoundRect(xY, yY, size, size, 8, RED);
  M5.Lcd.fillRoundRect(xA, yA, size, size, 8, BLUE);
  M5.Lcd.fillRoundRect(xB, yB, size, size, 8, GREEN);

  M5.Lcd.setTextSize(2);
  M5.Lcd.setTextColor(BLACK);

  M5.Lcd.setCursor(xX + 18, yX + 15); M5.Lcd.print("X");
  M5.Lcd.setCursor(xY + 18, yY + 15); M5.Lcd.print("Y");
  M5.Lcd.setCursor(xA + 18, yA + 15); M5.Lcd.print("A");
  M5.Lcd.setCursor(xB + 18, yB + 15); M5.Lcd.print("B");
}

void startFreeze() {
  isFrozen = true;
  freezeStartTime = millis();
  Serial.println("FROZEN!");
}

void updateFreeze() {
  if (isFrozen && millis() - freezeStartTime >= freezeDuration) {
    isFrozen = false;
    Serial.println("Unfrozen!");
    M5.Lcd.fillScreen(BLACK);
  }
}

void drawFreezeOverlay() {
  // Light blue "overlay"
  uint16_t freezeColor = M5.Lcd.color565(100, 180, 255);

  M5.Lcd.fillRect(0, 0, 320, 240, freezeColor);

  M5.Lcd.setTextSize(3);
  M5.Lcd.setTextColor(WHITE);
  M5.Lcd.setCursor(90, 110);
  M5.Lcd.print("FROZEN");
}

void waitingScreen() {
  static bool drawn = false;
  static int dots = 0;
  static unsigned long lastDotTime = 0;

  // Draw the static text only once
  if (!drawn) {
    M5.Lcd.fillScreen(BLACK);
    M5.Lcd.setTextSize(2);
    M5.Lcd.setTextColor(WHITE);
    M5.Lcd.setCursor(30, 90);
    M5.Lcd.print("Waiting for");
    M5.Lcd.setCursor(55, 115);
    M5.Lcd.print("phone...");
    drawn = true;
  }

  // Only update the dots every 500ms
  if (millis() - lastDotTime > 500) {
    dots = (dots + 1) % 4;
    lastDotTime = millis();
    M5.Lcd.fillRect(55, 140, 100, 20, BLACK);
    M5.Lcd.setCursor(55, 140);
    for (int i = 0; i < dots; i++) M5.Lcd.print(".");
  }
}
