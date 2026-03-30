# Fruit Assassin — Flutter Client

A simplified Fruit Ninja clone where a human saboteur on an **M5Core2** 
can disrupt the Flutter player over **Bluetooth Low Energy (BLE)**.

---

## Project Structure

```
lib/
├── main.dart                  # App entry point
├── constants.dart             # All tunable game values (points, timings, assets)
│
├── ble/
│   └── ble_manager.dart       # BLE scan/connect, receive sabotage, send freeze
│
├── game/
│   ├── fruit_ninja_game.dart  # Root FlameGame — wires everything together
│   ├── fruit_component.dart   # Fruit physics, spawn logic, slice detection
│   ├── slice_detector.dart    # Swipe gesture overlay + visual trail
│   ├── game_state.dart        # Points, freeze logic, win/loss state
│   ├── sabotage_handler.dart  # Maps BLE commands to in-game effects (TODO stubs)
│   └── hud_overlay.dart       # Flutter HUD: score, freeze button, banners
│
└── screens/
    ├── menu_screen.dart        # BLE connect + start game
    └── game_screen.dart        # Hosts Flame canvas + HUD overlay
```

---

## Quick-Start Checklist

### 1. Fill in the TODOs in `constants.dart`
| Constant | What to set |
|---|---|
| `pointsToWin` | Points the player needs to win |
| `pointsToFreeze` | Points spent to freeze the saboteur |
| `freezeDurationSeconds` | How long (seconds) the saboteur stays frozen |
| `fruitImagePaths` | Swap placeholders for your real fruit PNG paths |

### 2. Fill in BLE UUIDs in `ble/ble_manager.dart`
- `kServiceUUID` — your M5Core2's GATT service UUID  
- `kSabotageCharUUID` — characteristic the M5 notifies on (M5 → Flutter)  
- `kFreezeCharUUID` — characteristic Flutter writes to (Flutter → M5)  
- `kM5DeviceName` — exact BLE advertisement name from your M5 firmware

### 3. Map sabotage commands in `ble/ble_manager.dart`
In `_parseCommand()`, add a `case` for every string your M5 firmware sends 
and map it to a `SabotageCommand` enum value.

### 4. Implement sabotage effects in `game/sabotage_handler.dart`
Each `_handleXxx()` stub has a comment describing a suggested approach.
Implement whatever effects you want the saboteur to trigger.

### 5. Add freeze payload in `ble/ble_manager.dart`
In `sendFreeze()` / `sendUnfreeze()`, set the byte payload to match what 
your M5Core2 firmware expects when it receives the freeze signal.

### 6. Add your "fruit" images
Drop PNG files into `assets/images/` and update `pubspec.yaml` + 
`GameConstants.fruitImagePaths`. Then replace the `canvas.drawCircle` 
rendering in `FruitComponent.render()` with a `SpriteComponent`.

### 7. Android BLE permissions
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### 8. iOS BLE permissions
Add to `ios/Runner/Info.plist`:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Used to connect to the saboteur device.</string>
```

---

## Game Flow

```
Menu Screen
  └─ [Connect to M5Core2 over BLE]
       └─ [START GAME]
            └─ Game Screen
                 ├── Flame canvas: fruits arc up, player swipes to slice
                 ├── HUD: score / win progress / freeze button
                 └── BLE: M5Core2 sends sabotage commands in real-time
                          Player can spend points to freeze the saboteur
```

## How the Freeze Works

1. Player taps **FREEZE** button (costs `pointsToFreeze` points).  
2. Flutter writes `"freeze"` to the M5's BLE characteristic.  
3. `GameState` sets `saboteurFrozen = true` — all incoming sabotage 
   commands are silently dropped for `freezeDurationSeconds` seconds.  
4. After the timer expires, Flutter writes `"unfreeze"` to the M5.
