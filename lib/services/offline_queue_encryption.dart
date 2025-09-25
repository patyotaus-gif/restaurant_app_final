import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
/// Manages encryption of offline queue payloads using an AES-GCM keyring.
///
/// Keys are stored locally in [SharedPreferences] so that encrypted payloads can
/// be decrypted across restarts. The manager keeps a rolling keyring and
/// supports key rotation to limit exposure if a key is compromised.
class OfflineQueueEncryption {
  OfflineQueueEncryption({SharedPreferences? initialPrefs})
      : _prefs = initialPrefs,
        _cipher = AesGcm.with256bits(),
        _random = Random.secure();

  static const _keyringPref = 'sync_queue_keyring_v1';
  static const _activeKeyIdPref = 'sync_queue_active_key_id_v1';

  final Cipher _cipher;
  final Random _random;

  SharedPreferences? _prefs;
  List<_KeyEntry>? _keyring;
  String? _activeKeyId;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Encrypts a JSON serialisable payload and returns a base64 encoded blob.
  Future<String> encryptPayload(Map<String, dynamic> payload) async {
    await _ensureKeyring();
    final key = _activeKey;
    final secretKey = SecretKey(base64Decode(key.value));
    final nonce = _randomBytes(12);
    final bytes = utf8.encode(jsonEncode(payload));
    final box = await _cipher.encrypt(
      bytes,
      secretKey: secretKey,
      nonce: nonce,
    );
    final encoded = <String, dynamic>{
      'keyId': key.id,
      'nonce': base64Encode(box.nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
    return jsonEncode(encoded);
  }

  /// Decrypts a previously encrypted payload back into its JSON structure.
  Future<Map<String, dynamic>> decryptPayload(String encrypted) async {
    await _ensureKeyring();
    final decoded = jsonDecode(encrypted);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected encrypted payload format');
    }
    final keyId = decoded['keyId'] as String?;
    if (keyId == null) {
      throw const FormatException('Encrypted payload missing keyId');
    }
    final key = _keyring!.firstWhere(
      (entry) => entry.id == keyId,
      orElse: () => throw StateError('Unknown keyId $keyId for queue payload'),
    );
    final secretKey = SecretKey(base64Decode(key.value));
    final nonce = base64Decode(decoded['nonce'] as String);
    final cipherText = base64Decode(decoded['cipherText'] as String);
    final macBytes = base64Decode(decoded['mac'] as String);
    final box = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );
    final decrypted = await _cipher.decrypt(
      box,
      secretKey: secretKey,
    );
    final jsonMap = jsonDecode(utf8.decode(decrypted));
    if (jsonMap is! Map<String, dynamic>) {
      throw const FormatException('Decrypted payload is not a JSON object');
    }
    return jsonMap;
  }

  /// Rotates the encryption key and re-encrypts provided payloads.
  ///
  /// Returns the payloads encrypted with the freshly generated key.
  Future<List<String>> rotateKeyAndReencrypt(List<String> encryptedPayloads) async {
    await _ensureKeyring();
    final newKey = _generateKey();
    _keyring!.add(newKey);
    _activeKeyId = newKey.id;
    await _persistKeyring();

    final reencrypted = <String>[];
    for (final payload in encryptedPayloads) {
      try {
        final json = await decryptPayload(payload);
        final encrypted = await encryptPayload(json);
        reencrypted.add(encrypted);
      } catch (error, stackTrace) {
        debugPrint('Failed to re-encrypt queue payload: $error');
        debugPrint(stackTrace.toString());
        reencrypted.add(payload);
      }
    }

    _pruneKeyring();
    await _persistKeyring();
    return reencrypted;
  }

  Future<void> _ensureKeyring() async {
    if (_keyring != null && _activeKeyId != null) {
      return;
    }
    final prefs = await _getPrefs();
    final stored = prefs.getStringList(_keyringPref) ?? <String>[];
    _keyring = stored
        .map((raw) => _KeyEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>))
        .toList();
    _activeKeyId = prefs.getString(_activeKeyIdPref);
    if (_keyring!.isEmpty ||
        _activeKeyId == null ||
        !_keyring!.any((entry) => entry.id == _activeKeyId)) {
      final key = _generateKey();
      _keyring!
        ..clear()
        ..add(key);
      _activeKeyId = key.id;
      await _persistKeyring();
    }
  }

  void _pruneKeyring({int keep = 3}) {
    if (_keyring!.length <= keep) {
      return;
    }
    _keyring!.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final retained = _keyring!.take(keep).toList(growable: false);
    _keyring!
      ..clear()
      ..addAll(retained);
    if (!_keyring!.any((entry) => entry.id == _activeKeyId)) {
      _activeKeyId = _keyring!.first.id;
    }
  }

  Future<void> _persistKeyring() async {
    final prefs = await _getPrefs();
    final encoded = _keyring!
        .map((entry) => jsonEncode(entry.toJson()))
        .toList(growable: false);
    await prefs.setStringList(_keyringPref, encoded);
    await prefs.setString(_activeKeyIdPref, _activeKeyId!);
  }

  List<int> _randomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }

  _KeyEntry get _activeKey {
    return _keyring!.firstWhere((entry) => entry.id == _activeKeyId);
  }

  _KeyEntry _generateKey() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final keyData = List<int>.generate(32, (_) => _random.nextInt(256));
    return _KeyEntry(
      id: id,
      value: base64Encode(keyData),
      createdAt: DateTime.now(),
    );
  }
}

class _KeyEntry {
  _KeyEntry({
    required this.id,
    required this.value,
    required this.createdAt,
  });

  factory _KeyEntry.fromJson(Map<String, dynamic> json) {
    return _KeyEntry(
      id: json['id'] as String,
      value: json['value'] as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String value;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'value': value,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
