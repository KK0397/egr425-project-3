import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// ============================================================
///  BLE SERVICE UUIDs — must match your M5Core2 firmware
/// ============================================================
// TODO: Replace these with the actual UUIDs from your M5Core2 code.
const String kServiceUUID        = '0000XXXX-0000-1000-8000-00805F9B34FB';
const String kSabotageCharUUID   = '0000YYYY-0000-1000-8000-00805F9B34FB'; // M5 → Flutter (notify)
const String kFreezeCharUUID     = '0000ZZZZ-0000-1000-8000-00805F9B34FB'; // Flutter → M5 (write)

/// Names the M5Core2 advertises — adjust to match your firmware.
const String kM5DeviceName = 'M5Core2_Saboteur'; // TODO: match your BLE device name

/// ============================================================
///  Sabotage command types sent by the M5Core2
/// ============================================================
enum SabotageCommand {
  unknown,

  // TODO: Add every command your M5Core2 can send and map them
  // in the _parseCommand() method below. Examples are provided
  // to illustrate the pattern — replace or extend as needed.
  spawnBomb,     // example: spawns an on-screen bomb the player must avoid
  slowSlicing,   // example: temporarily slows the player's slice detection window
  invertControls,// example: flips swipe direction
}

/// ============================================================
///  BLE Manager
/// ============================================================
class BleManager {
  BleManager._();
  static final BleManager instance = BleManager._();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _sabotageChar;
  BluetoothCharacteristic? _freezeChar;

  final StreamController<SabotageCommand> _sabotageController =
      StreamController<SabotageCommand>.broadcast();

  /// Stream of sabotage commands received from the M5Core2.
  Stream<SabotageCommand> get sabotageStream => _sabotageController.stream;

  bool _connected = false;
  bool get isConnected => _connected;

  // ── Scanning ────────────────────────────────────────────────

  /// Scan for the M5Core2 and connect automatically when found.
  Future<void> scanAndConnect() async {
    await FlutterBluePlus.startScan(
      withServices: [Guid(kServiceUUID)],
      timeout: const Duration(seconds: 15),
    );

    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.platformName == kM5DeviceName || 
            r.advertisementData.serviceUuids
                .contains(Guid(kServiceUUID))) {
          await FlutterBluePlus.stopScan();
          await _connectToDevice(r.device);
          break;
        }
      }
    });
  }

  // ── Connection ──────────────────────────────────────────────

  Future<void> _connectToDevice(BluetoothDevice device) async {
    _device = device;
    await device.connect(autoConnect: false);
    _connected = true;

    device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _connected = false;
        // Optionally attempt reconnect here
      }
    });

    await _discoverServices(device);
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    final services = await device.discoverServices();
    for (BluetoothService service in services) {
      if (service.serviceUuid == Guid(kServiceUUID)) {
        for (BluetoothCharacteristic char in service.characteristics) {
          if (char.characteristicUuid == Guid(kSabotageCharUUID)) {
            _sabotageChar = char;
            await _subscribeToSabotage(char);
          }
          if (char.characteristicUuid == Guid(kFreezeCharUUID)) {
            _freezeChar = char;
          }
        }
      }
    }
  }

  // ── Receiving sabotage commands ─────────────────────────────

  Future<void> _subscribeToSabotage(BluetoothCharacteristic char) async {
    await char.setNotifyValue(true);
    char.lastValueStream.listen((value) {
      if (value.isEmpty) return;
      final raw = utf8.decode(value);
      final cmd = _parseCommand(raw);
      _sabotageController.add(cmd);
    });
  }

  /// Maps the raw string sent by the M5Core2 to a [SabotageCommand].
  ///
  /// TODO: Update the case strings to match exactly what your
  /// M5Core2 firmware writes over BLE. The examples below are
  /// illustrative — replace or extend them freely.
  SabotageCommand _parseCommand(String raw) {
    final trimmed = raw.trim().toLowerCase();
    switch (trimmed) {
      case 'spawn_bomb':      return SabotageCommand.spawnBomb;
      case 'slow_slicing':    return SabotageCommand.slowSlicing;
      case 'invert_controls': return SabotageCommand.invertControls;
      // TODO: add more cases matching your M5 firmware commands
      default:                return SabotageCommand.unknown;
    }
  }

  // ── Sending freeze to M5Core2 ───────────────────────────────

  /// Writes a "freeze" notification to the M5Core2 over BLE.
  ///
  /// TODO: Adjust the payload string/bytes to match what your
  /// M5Core2 firmware expects when it receives the freeze command.
  Future<void> sendFreeze() async {
    if (_freezeChar == null) return;
    final payload = utf8.encode('freeze'); // TODO: match your M5 protocol
    await _freezeChar!.write(payload, withoutResponse: false);
  }

  /// Writes an "unfreeze" notification so the M5 knows freeze ended.
  Future<void> sendUnfreeze() async {
    if (_freezeChar == null) return;
    final payload = utf8.encode('unfreeze'); // TODO: match your M5 protocol
    await _freezeChar!.write(payload, withoutResponse: false);
  }

  // ── Cleanup ─────────────────────────────────────────────────

  Future<void> disconnect() async {
    await _device?.disconnect();
    _connected = false;
  }

  void dispose() {
    _sabotageController.close();
  }
}
