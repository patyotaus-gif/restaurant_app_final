import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_models/restaurant_models.dart';

class PrinterDrawerException implements Exception {
  PrinterDrawerException(this.message);

  final String message;
  @override
  String toString() => 'PrinterDrawerException: $message';
}

import 'dart:io';

class PrinterDrawerService {
  CapabilityProfile? _profile;

  Future<void> printReceipt({
    required String host,
    required Map<String, dynamic> orderData,
    required StoreReceiptDetails storeDetails,
    TaxInvoiceDetails? taxDetails,
    int port = 9100,
    PaperSize paperSize = PaperSize.mm80,
  }) async {
    await _loadProfile();
    final payload = <String, dynamic>{
      'order': _sanitizeOrderData(orderData),
      'store': storeDetails.toMap(),
      'paperSize': paperSize.name,
      if (taxDetails != null && taxDetails.hasData) 'tax': taxDetails.toMap(),
    };

    final bytes = await compute(_renderReceiptBytes, payload);
    await _sendBytes(host: host, port: port, bytes: bytes);
  }

  Future<void> openCashDrawer({required String host, int port = 9100}) async {
    const command = <int>[27, 112, 0, 64, 240];
    await _sendBytes(host: host, port: port, bytes: command);
  }

  Future<CapabilityProfile> _loadProfile() async {
    if (_profile != null) {
      return _profile!;
    }
    _profile = await CapabilityProfile.load();
    return _profile!;
  }

  Future<void> _sendBytes({
    required String host,
    required int port,
    required List<int> bytes,
  }) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      socket.add(bytes);
      await socket.flush();
      await socket.close();
    } on SocketException catch (e) {
      throw PrinterDrawerException(
        'Failed to reach printer at $host:$port (${e.message})',
      );
    }
  }
}
