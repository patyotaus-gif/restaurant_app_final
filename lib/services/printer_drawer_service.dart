import 'dart:async';
import 'dart:io';

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
      'paperSize': describeEnum(paperSize),
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

Map<String, dynamic> _sanitizeOrderData(Map<String, dynamic> raw) {
  final Map<String, dynamic> sanitized = <String, dynamic>{};

  final dynamic timestamp = raw['timestamp'];
  if (timestamp is Timestamp) {
    sanitized['timestamp'] = timestamp.toDate().toIso8601String();
  } else if (timestamp is DateTime) {
    sanitized['timestamp'] = timestamp.toIso8601String();
  } else if (timestamp is String) {
    sanitized['timestamp'] = timestamp;
  }

  void writeDouble(String key, String sourceKey) {
    final double? value = (raw[sourceKey] as num?)?.toDouble();
    if (value != null) {
      sanitized[key] = value;
    }
  }

  sanitized['orderIdentifier'] = raw['orderIdentifier']?.toString();
  sanitized['id'] = raw['id']?.toString();
  writeDouble('subtotal', 'subtotal');
  writeDouble('discount', 'discount');
  writeDouble('serviceCharge', 'serviceChargeAmount');
  writeDouble('tip', 'tipAmount');
  writeDouble('total', 'total');
  writeDouble('paidTotal', 'paidTotal');

  final Map<String, dynamic> vat =
      (raw['vat'] as Map<String, dynamic>?) ?? <String, dynamic>{};
  if (vat.isNotEmpty) {
    final double? amount = (vat['amount'] as num?)?.toDouble();
    if (amount != null) {
      sanitized['vatAmount'] = amount;
    }
  }

  sanitized['items'] = (raw['items'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(
        (item) => <String, dynamic>{
          'name': item['name']?.toString(),
          'quantity': (item['quantity'] as num?)?.toDouble() ?? 0.0,
          'price': (item['price'] as num?)?.toDouble(),
          'total': (item['total'] as num?)?.toDouble(),
        },
      )
      .toList();

  sanitized['payments'] = (raw['payments'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(
        (payment) => <String, dynamic>{
          'method': payment['method']?.toString(),
          'amount': (payment['amount'] as num?)?.toDouble() ?? 0.0,
        },
      )
      .toList();

  return sanitized;
}

Future<List<int>> _renderReceiptBytes(Map<String, dynamic> payload) async {
  final Map<String, dynamic> order = Map<String, dynamic>.from(
    payload['order'] as Map<String, dynamic>? ?? {},
  );
  final Map<String, dynamic> store = Map<String, dynamic>.from(
    payload['store'] as Map<String, dynamic>? ?? {},
  );
  final Map<String, dynamic>? tax = payload['tax'] != null
      ? Map<String, dynamic>.from(payload['tax'] as Map<String, dynamic>)
      : null;
  final String? paperSizeName = payload['paperSize'] as String?;
  final PaperSize paperSize = _paperSizeFromStorageKey(paperSizeName);

  final CapabilityProfile profile = await CapabilityProfile.load();
  final generator = Generator(paperSize, profile);
  final List<int> bytes = <int>[];

  final String storeName = store['name']?.toString() ?? 'Store';
  bytes.addAll(
    generator.text(
      storeName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ),
  );

  final List<String> headerLines = <String>[];
  final String? branch = store['branch'] as String?;
  if (branch != null && branch.isNotEmpty) {
    headerLines.add('Branch: $branch');
  }
  final String? address = store['address'] as String?;
  if (address != null && address.isNotEmpty) {
    headerLines.add(address);
  }
  final String? phone = store['phone'] as String?;
  if (phone != null && phone.isNotEmpty) {
    headerLines.add('Tel: $phone');
  }
  final String? taxId = store['taxId'] as String?;
  if (taxId != null && taxId.isNotEmpty) {
    headerLines.add('Tax ID: $taxId');
  }
  for (final String line in headerLines) {
    bytes.addAll(
      generator.text(line, styles: const PosStyles(align: PosAlign.center)),
    );
  }

  final String? timestamp = order['timestamp'] as String?;
  DateTime orderDate = DateTime.now();
  if (timestamp != null) {
    final DateTime? parsed = DateTime.tryParse(timestamp);
    if (parsed != null) {
      orderDate = parsed;
    }
  }
  final String orderId =
      order['orderIdentifier']?.toString() ?? order['id']?.toString() ?? '';

  bytes.addAll(generator.text('-----------------------------'));
  bytes.addAll(generator.text('Order: $orderId'));
  bytes.addAll(
    generator.text(DateFormat('dd/MM/yyyy HH:mm').format(orderDate)),
  );

  if (tax != null && tax.isNotEmpty) {
    bytes.addAll(generator.text('--- Tax Invoice ---'));
    final String? customerName = tax['customerName'] as String?;
    if (customerName != null && customerName.isNotEmpty) {
      bytes.addAll(generator.text('Name: $customerName'));
    }
    final String? customerTaxId = tax['taxId'] as String?;
    if (customerTaxId != null && customerTaxId.isNotEmpty) {
      bytes.addAll(generator.text('Tax ID: $customerTaxId'));
    }
    final String? taxAddress = tax['address'] as String?;
    if (taxAddress != null && taxAddress.isNotEmpty) {
      bytes.addAll(generator.text('Address: $taxAddress'));
    }
    final String? email = tax['email'] as String?;
    if (email != null && email.isNotEmpty) {
      bytes.addAll(generator.text('Email: $email'));
    }
    final String? taxPhone = tax['phone'] as String?;
    if (taxPhone != null && taxPhone.isNotEmpty) {
      bytes.addAll(generator.text('Phone: $taxPhone'));
    }
    bytes.addAll(generator.text('-----------------------------'));
  }

  final List<dynamic> items = order['items'] as List<dynamic>? ?? <dynamic>[];
  if (items.isNotEmpty) {
    bytes.addAll(generator.text('Items', styles: const PosStyles(bold: true)));
    for (final dynamic raw in items) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final String name = raw['name']?.toString() ?? 'Item';
      final double quantity = (raw['quantity'] as num?)?.toDouble() ?? 1.0;
      final double price = (raw['price'] as num?)?.toDouble() ?? 0.0;
      final double total =
          (raw['total'] as num?)?.toDouble() ?? price * quantity;
      bytes.addAll(generator.text(name));
      bytes.addAll(
        generator.row([
          PosColumn(
            width: 6,
            text: 'x${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 2)}',
          ),
          PosColumn(
            width: 6,
            text: total.toStringAsFixed(2),
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
    }
  }

  bytes.addAll(generator.text('-----------------------------'));
  final double? subtotal = (order['subtotal'] as num?)?.toDouble();
  final double? discount = (order['discount'] as num?)?.toDouble();
  final double? serviceCharge = (order['serviceCharge'] as num?)?.toDouble();
  final double? tip = (order['tip'] as num?)?.toDouble();
  final double? vatAmount = (order['vatAmount'] as num?)?.toDouble();
  final double total =
      (order['total'] as num?)?.toDouble() ??
      (order['paidTotal'] as num?)?.toDouble() ??
      0.0;

  void addAmountRow(String label, double amount) {
    bytes.addAll(
      generator.row([
        PosColumn(width: 6, text: label),
        PosColumn(
          width: 6,
          text: amount.toStringAsFixed(2),
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]),
    );
  }

  if (subtotal != null) {
    addAmountRow('Subtotal', subtotal);
  }
  if (discount != null && discount != 0) {
    addAmountRow('Discount', -discount.abs());
  }
  if (serviceCharge != null && serviceCharge != 0) {
    addAmountRow('Service', serviceCharge);
  }
  if (tip != null && tip != 0) {
    addAmountRow('Tip', tip);
  }
  if (vatAmount != null && vatAmount != 0) {
    addAmountRow('VAT', vatAmount);
  }
  addAmountRow('TOTAL', total);

  final List<dynamic> payments =
      order['payments'] as List<dynamic>? ?? <dynamic>[];
  if (payments.isNotEmpty) {
    bytes.addAll(
      generator.text('Payments', styles: const PosStyles(bold: true)),
    );
    for (final dynamic paymentRaw in payments) {
      if (paymentRaw is! Map<String, dynamic>) {
        continue;
      }
      final String method = paymentRaw['method']?.toString() ?? 'Payment';
      final double amount = (paymentRaw['amount'] as num?)?.toDouble() ?? 0.0;
      bytes.addAll(
        generator.row([
          PosColumn(width: 6, text: method),
          PosColumn(
            width: 6,
            text: amount.toStringAsFixed(2),
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
    }
  }

  bytes.addAll(generator.feed(2));
  bytes.addAll(
    generator.text(
      'Thank you!',
      styles: const PosStyles(align: PosAlign.center),
    ),
  );
  bytes.addAll(generator.cut());

  return bytes;
}

PaperSize _paperSizeFromStorageKey(String? key) {
  if (key == null) {
    return PaperSize.mm80;
  }
  const List<PaperSize> supportedPaperSizes = <PaperSize>[
    PaperSize.mm58,
    PaperSize.mm80,
  ];
  for (final PaperSize value in supportedPaperSizes) {
    if (describeEnum(value) == key) {
      return value;
    }
  }
  return PaperSize.mm80;
}
