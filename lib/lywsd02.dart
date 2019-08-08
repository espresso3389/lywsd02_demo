// Client for Xiaomi Mijia Clock
// This code is based on the following code:
// https://github.com/h4/lywsd02/blob/master/lywsd02/client.py

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:rxdart/rxdart.dart';

enum _ScanResult {
  skip,
  found,
  stopScan,
}

Future<BluetoothDevice> _scan(_ScanResult Function(ScanResult) onDevice, {Duration timeout}) async {
  StreamSubscription<ScanResult> sub;
  try {
    await FlutterBlue.instance.stopScan(); // In case a scan is already running
    final comp = Completer<BluetoothDevice>();
    sub = FlutterBlue.instance.scan(timeout: timeout).listen((scanResult) {
      final code = onDevice(scanResult);
      if (code == _ScanResult.skip) {
        return;
      } else if (code == _ScanResult.found) {
        comp.complete(scanResult.device);
      } else {
        comp.complete(null);
      }
    },
    onError: (error) => comp.completeError(error));
    return await comp.future;
  } finally {
    await FlutterBlue.instance.stopScan();
    sub?.cancel();
  }
}

enum Lywsd02TempertureUnit {
  fahrenheit,
  celsius
}

class Lywsd02Data {
  final double temperature;
  final Lywsd02TempertureUnit tempUnit;
  final int humidity;
  Lywsd02Data({this.temperature, this.tempUnit, this.humidity});
}

class Lywsd02Client {
  static final UUID_UNITS = Guid('EBE0CCBE-7A0A-4B0C-8A1A-6FF2997DA3A6');   // 0x00 - F, 0x01 - C    READ WRITE
  static final UUID_HISTORY = Guid('EBE0CCBC-7A0A-4B0C-8A1A-6FF2997DA3A6'); // Last idx 152          READ NOTIFY
  static final UUID_TIME = Guid('EBE0CCB7-7A0A-4B0C-8A1A-6FF2997DA3A6');    // 5 bytes               READ WRITE
  static final UUID_DATA = Guid('EBE0CCC1-7A0A-4B0C-8A1A-6FF2997DA3A6');    // 3 bytes               READ NOTIFY

  BluetoothDevice _device;
  BluetoothCharacteristic _timeChar, _unitsChar, _dataChar;
  StreamSubscription<List<int>> _dataSub;
  PublishSubject<Lywsd02Data> _pub;

  Lywsd02Client._();

  Future<void> _init(BluetoothDevice device) async {
    _device = device;
    await device.connect();
    final services = await device.discoverServices();
    _timeChar = _findCharacteristic(services: services, uuidChar: UUID_TIME);
    _unitsChar = _findCharacteristic(services: services, uuidChar: UUID_UNITS);
    _dataChar = _findCharacteristic(services: services, uuidChar: UUID_DATA);
    _pub = PublishSubject<Lywsd02Data>();
  }

  static Future<Lywsd02Client> discoverDevice({Duration timeout}) async {
    final device = await _scan((result) => result.device.name == 'LYWSD02' ? _ScanResult.found : _ScanResult.skip);
    if (device == null) {
      return null;
    }
    final client = Lywsd02Client._();
    await client._init(device);
    return client;
  }

  Future<void> disconnect() async {
    stop();
    await _device?.disconnect();
    _device = null;
  }

  Future<void> setClock(DateTime dateTime, {int tzHours}) async {
    final now = dateTime.millisecondsSinceEpoch ~/ 1000;
    final t = List<int>(5);
    t[0] = now & 0xff;
    t[1] = (now >> 8) & 0xff;
    t[2] = (now >> 16) & 0xff;
    t[3] = (now >> 24) & 0xff;
    t[4] = tzHours ?? dateTime.timeZoneOffset.inHours;
    await _timeChar.write(t, withoutResponse: false);
  }

  Future<void> syncClock() => setClock(DateTime.now());

  Future<Lywsd02TempertureUnit> getTempertureUnit() async {
    return (await _unitsChar.read())[0] == 0 ? Lywsd02TempertureUnit.fahrenheit : Lywsd02TempertureUnit.celsius; // 0: Fahrenheit/ 0xff: Celsius
  }

  Future<void> setTempertureUnit(Lywsd02TempertureUnit unit) async {
    await _unitsChar.write([unit == Lywsd02TempertureUnit.fahrenheit ? 0 : 0xff], withoutResponse: false);
  }

  Stream<Lywsd02Data> get stream => _pub.stream;

  Future<void> start() async {
    final tempUnit = await getTempertureUnit(); // FIXME: Basically, it may be changed during the instrumention...
    _dataChar.setNotifyValue(true);
    _dataSub = _dataChar.value.listen((data) {
      if (data.length == 3) {
        _pub.add(Lywsd02Data(temperature: (data[0] + data[1] * 255) / 100, tempUnit: tempUnit, humidity: data[2]));
      }
    });
  }

  void stop() {
    _dataSub?.cancel();
    _dataSub = null;
  }

  static BluetoothCharacteristic _findCharacteristic({@required List<BluetoothService> services, @required Guid uuidChar, Guid uuidService}) {
    if (uuidService != null) {
       return services.firstWhere((s) => s.uuid == uuidService, orElse: () => null)?.characteristics?.firstWhere((c) => c.uuid == uuidChar, orElse: () => null);
    }
    for (var s in services) {
      final char = s.characteristics.firstWhere((c) => c.uuid == uuidChar, orElse: () => null);
      if (char != null)
        return char;
    }
    return null;
  }
}

