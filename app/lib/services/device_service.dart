import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Produces a stable, privacy-friendly device fingerprint used to prevent
/// repeated free trials on the same device.
///
/// Strategy: generate a UUID once and persist it in secure storage. We mix in
/// a coarse hardware signal (model/vendor id) for resilience, but the stored
/// UUID is the source of truth so the value survives across app launches.
class DeviceService {
  DeviceService({
    FlutterSecureStorage? storage,
    DeviceInfoPlugin? deviceInfo,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  static const _key = 'mw_device_id';

  final FlutterSecureStorage _storage;
  final DeviceInfoPlugin _deviceInfo;

  String? _cached;

  /// Returns the persistent device id, creating one on first run.
  Future<String> deviceId() async {
    if (_cached != null) return _cached!;

    final existing = await _storage.read(key: _key);
    if (existing != null && existing.isNotEmpty) {
      _cached = existing;
      return existing;
    }

    final generated = await _generate();
    await _storage.write(key: _key, value: generated);
    _cached = generated;
    return generated;
  }

  Future<String> _generate() async {
    final uuid = const Uuid().v4();
    final hardware = await _hardwareTag();
    return hardware == null ? uuid : '$hardware-$uuid';
  }

  /// A coarse, non-resettable hardware tag where available. Best-effort only.
  Future<String?> _hardwareTag() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await _deviceInfo.androidInfo;
        return 'and_${info.model}';
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await _deviceInfo.iosInfo;
        return 'ios_${info.identifierForVendor ?? info.model}';
      }
    } catch (_) {
      // Fingerprinting is best-effort; fall back to UUID only.
    }
    return null;
  }
}
