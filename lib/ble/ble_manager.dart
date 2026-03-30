import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// ── UUIDs: copied exactly from your M5Core2 firmware ──────────
const String kServiceUUID = '12345678-1234-1234-1234-123456789abc';
const String kMainCharUUID = 'abcd1234-5678-1234-5678-123456789abc';
// The M5 uses ONE characteristic for notify + write, so both point here.

const String kM5DeviceName = 'Fruit Assassin'; // matches BLEDevice::init()

enum SabotageCommand {
  unknown,
  spawnBomb,
  blind,
  saboteurWin,
  // Add more as you wire them up on the M5 side
}

class BleManager {
  BleManager._();
  static final BleManager instance = BleManager._();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _mainChar; // single char for both RX and TX

  final StreamController<SabotageCommand> _sabotageController =
      StreamController<SabotageCommand>.broadcast();

  Stream<SabotageCommand> get sabotageStream => _sabotageController.stream;

  bool _connected = false;
  bool get isConnected => _connected;

  // ── Scanning ───────────────────────────────────────────────

  bool _connecting = false; // add this as a class field in BleManager

  Future<void> scanAndConnect() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    final allGranted = statuses.values.every((s) => s.isGranted);
    if (!allGranted) throw Exception('Bluetooth permissions denied');

    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      throw Exception('Bluetooth is not enabled');
    }

    final completer = Completer<void>();

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

    final sub = FlutterBluePlus.scanResults.listen((results) async {
      if (completer.isCompleted) return; // guard against duplicate fires
      for (ScanResult r in results) {
        print('Found device: ${r.device.platformName}');
        if (r.device.platformName == kM5DeviceName) {
          await FlutterBluePlus.stopScan();
          await _connectToDevice(r.device);
          completer.complete();
          return;
        }
      }
    });

    // Timeout fallback — fires after 15s if nothing connected
    Future.delayed(const Duration(seconds: 16), () {
      if (!completer.isCompleted) {
        completer.completeError(
            Exception('Device not found — is M5Core2 on and advertising?'));
      }
    });

    try {
      await completer.future;
    } finally {
      await sub.cancel();
    }
  }

  // ── Connection ─────────────────────────────────────────────

  Future<void> _connectToDevice(BluetoothDevice device) async {
    _device = device;
    await device.connect(autoConnect: false, license: License.free);
    _connected = true;

    device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _connected = false;
      }
    });

    await _discoverServices(device);
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    final services = await device.discoverServices();
    for (BluetoothService service in services) {
      if (service.serviceUuid == Guid(kServiceUUID)) {
        for (BluetoothCharacteristic char in service.characteristics) {
          if (char.characteristicUuid == Guid(kMainCharUUID)) {
            _mainChar = char;
            await _subscribeToCommands(char);
          }
        }
      }
    }
  }

  // ── Receiving commands from M5 ─────────────────────────────

  Future<void> _subscribeToCommands(BluetoothCharacteristic char) async {
    await char.setNotifyValue(true);
    char.lastValueStream.listen((value) {
      if (value.isEmpty) return;
      final raw = utf8.decode(value);
      final cmd = _parseCommand(raw);
      if (cmd != SabotageCommand.unknown) {
        _sabotageController.add(cmd);
      }
    });
  }

  SabotageCommand _parseCommand(String raw) {
    switch (raw.trim().toUpperCase()) {
      // These strings must match exactly what your M5 firmware
      // passes to pCharacteristic->setValue() / notify()
      case 'BOMB':
        return SabotageCommand.spawnBomb;
      case 'BLIND':
        return SabotageCommand.blind;
      case 'SABOTEUR_WIN':
        return SabotageCommand.saboteurWin;
      default:
        return SabotageCommand.unknown;
    }
  }

  // ── Sending freeze to M5 ───────────────────────────────────

  Future<void> sendFreeze() async {
    if (_mainChar == null) return;
    // M5 checks:  if (value == "FREEZE")  — must be uppercase
    await _mainChar!.write(utf8.encode('FREEZE'), withoutResponse: false);
  }

  Future<void> sendUnfreeze() async {
    if (_mainChar == null) return;
    await _mainChar!.write(utf8.encode('UNFREEZE'), withoutResponse: false);
  }

  //  Sending win to M5
  Future<void> sendWin() async {
    if (_mainChar == null) return;
    await _mainChar!.write(utf8.encode('WIN'), withoutResponse: false);
  }

  // ── Cleanup ────────────────────────────────────────────────

  Future<void> disconnect() async {
    await _device?.disconnect();
    _connected = false;
  }

  void dispose() {
    _sabotageController.close();
  }
}
