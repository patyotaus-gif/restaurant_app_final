import 'dart:convert';

/// Utility responsible for generating EMVCo-compliant PromptPay QR payloads.
class PromptPayQrGenerator {
  const PromptPayQrGenerator._();

  /// Generates a PromptPay payload for the provided [promptPayId].
  ///
  /// The [promptPayId] can be a phone number, national ID, or e-Wallet ID.
  /// Non-numeric characters are stripped automatically. When a Thai phone
  /// number is supplied the country code prefix (0066) is added for you.
  ///
  /// An [amount] can be supplied to create a dynamic QR. When omitted, the QR
  /// acts as a static PromptPay target. Optional [merchantName] and
  /// [merchantCity] fields are included when provided to improve terminal
  /// readability. They are truncated to the EMVCo field length requirements.
  static String generate({
    required String promptPayId,
    double? amount,
    String? merchantName,
    String? merchantCity,
  }) {
    final normalizedId = _normalizePromptPayId(promptPayId);

    final payload = StringBuffer()
      ..write(_formatField('00', '01'))
      ..write(_formatField('01', amount != null && amount > 0 ? '12' : '11'))
      ..write(
        _formatField(
          '29',
          _formatField('00', _promptPayAid) +
              _formatField('01', normalizedId),
        ),
      )
      ..write(_formatField('52', '0000'))
      ..write(_formatField('53', _thaiBahtCurrencyCode));

    if (amount != null && amount > 0) {
      payload.write(_formatField('54', _formatAmount(amount)));
    }

    payload
      ..write(_formatField('58', 'TH'))
      ..writeIfValue('59', merchantName, maxLength: 25)
      ..writeIfValue('60', merchantCity, maxLength: 15);

    final withoutChecksum = payload.toString();
    final checksum = _calculateCrc16('${withoutChecksum}6304');
    return '${withoutChecksum}6304$checksum';
  }

  static const String _promptPayAid = 'A000000677010111';
  static const String _thaiBahtCurrencyCode = '764';

  static String _formatField(String id, String value) {
    final length = value.length.toString().padLeft(2, '0');
    return '$id$length$value';
  }

  static String _formatAmount(double amount) {
    return amount.toStringAsFixed(2);
  }

  static String _normalizePromptPayId(String id) {
    final digitsOnly = id.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      throw ArgumentError('PromptPay ID must contain numeric characters.');
    }

    if (digitsOnly.startsWith('0066')) {
      if (digitsOnly.length != 13) {
        throw ArgumentError(
          'PromptPay mobile numbers with country code must be 13 digits.',
        );
      }
      return digitsOnly;
    }

    if (digitsOnly.startsWith('66') && digitsOnly.length == 11) {
      return '00$digitsOnly';
    }

    if (digitsOnly.startsWith('0') && digitsOnly.length == 10) {
      return '0066${digitsOnly.substring(1)}';
    }

    // National ID (13 digits) or e-Wallet ID (15 digits) are already usable.
    if (digitsOnly.length == 13 || digitsOnly.length == 15) {
      return digitsOnly;
    }

    // As a fallback return the cleaned digits. PromptPay will validate on scan.
    return digitsOnly;
  }

  static String _calculateCrc16(String value) {
    final bytes = ascii.encode(value);
    var crc = 0xFFFF;

    for (final byte in bytes) {
      crc ^= (byte << 8);
      for (var i = 0; i < 8; i++) {
        final hasCarry = (crc & 0x8000) != 0;
        crc = (crc << 1) & 0xFFFF;
        if (hasCarry) {
          crc ^= 0x1021;
        }
      }
    }

    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}

extension on StringBuffer {
  void writeIfValue(String id, String? value, {required int maxLength}) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return;
    }

    final asciiOnly = trimmed.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    final limited = asciiOnly.length <= maxLength
        ? asciiOnly
        : asciiOnly.substring(0, maxLength);
    write(PromptPayQrGenerator._formatField(id, limited));
  }
}
