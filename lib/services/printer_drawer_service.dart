import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';

import '../models/receipt_models.dart';

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
    final profile = await _loadProfile();
    final generator = Generator(paperSize, profile);
    final bytes = <int>[];

    bytes.addAll(
      generator.text(
        storeDetails.name,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );

    final lines = <String>[];
    if (storeDetails.branch != null && storeDetails.branch!.isNotEmpty) {
      lines.add('Branch: ${storeDetails.branch}');
    }
    if (storeDetails.address != null && storeDetails.address!.isNotEmpty) {
      lines.add(storeDetails.address!);
    }
    if (storeDetails.phone != null && storeDetails.phone!.isNotEmpty) {
      lines.add('Tel: ${storeDetails.phone}');
    }
    if (storeDetails.taxId != null && storeDetails.taxId!.isNotEmpty) {
      lines.add('Tax ID: ${storeDetails.taxId}');
    }
    for (final line in lines) {
      bytes.addAll(
        generator.text(line, styles: const PosStyles(align: PosAlign.center)),
      );
    }

    final timestamp = orderData['timestamp'];
    DateTime? orderDate;
    if (timestamp is Timestamp) {
      orderDate = timestamp.toDate();
    } else if (timestamp is DateTime) {
      orderDate = timestamp;
    }
    orderDate ??= DateTime.now();
    final orderId = orderData['orderIdentifier'] ?? orderData['id'] ?? '';

    bytes.addAll(generator.text('-----------------------------'));
    bytes.addAll(generator.text('Order: $orderId'));
    bytes.addAll(
      generator.text(DateFormat('dd/MM/yyyy HH:mm').format(orderDate)),
    );

    if (taxDetails != null && taxDetails.hasData) {
      bytes.addAll(generator.text('--- Tax Invoice ---'));
      if (taxDetails.customerName?.isNotEmpty ?? false) {
        bytes.addAll(generator.text('Name: ${taxDetails.customerName}'));
      }
      if (taxDetails.taxId?.isNotEmpty ?? false) {
        bytes.addAll(generator.text('Tax ID: ${taxDetails.taxId}'));
      }
      if (taxDetails.address?.isNotEmpty ?? false) {
        bytes.addAll(generator.text('Address: ${taxDetails.address}'));
      }
      if (taxDetails.email?.isNotEmpty ?? false) {
        bytes.addAll(generator.text('Email: ${taxDetails.email}'));
      }
      if (taxDetails.phone?.isNotEmpty ?? false) {
        bytes.addAll(generator.text('Phone: ${taxDetails.phone}'));
      }
      bytes.addAll(generator.text('-----------------------------'));
    }

    final items = (orderData['items'] as List<dynamic>? ?? <dynamic>[]);
    if (items.isNotEmpty) {
      bytes.addAll(
        generator.text('Items', styles: const PosStyles(bold: true)),
      );
      for (final raw in items) {
        final item = raw as Map<String, dynamic>? ?? <String, dynamic>{};
        final name = item['name']?.toString() ?? 'Item';
        final quantity = (item['quantity'] as num?)?.toDouble() ?? 1;
        final price = (item['price'] as num?)?.toDouble() ?? 0;
        final total = (item['total'] as num?)?.toDouble() ?? price * quantity;
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
    final subtotal = (orderData['subtotal'] as num?)?.toDouble();
    final discount = (orderData['discount'] as num?)?.toDouble();
    final serviceCharge = (orderData['serviceChargeAmount'] as num?)
        ?.toDouble();
    final tip = (orderData['tipAmount'] as num?)?.toDouble();
    final vat = orderData['vat'] as Map<String, dynamic>?;
    final total =
        (orderData['total'] as num?)?.toDouble() ??
        (orderData['paidTotal'] as num?)?.toDouble() ??
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
    if (vat != null) {
      final vatAmount = (vat['amount'] as num?)?.toDouble();
      if (vatAmount != null && vatAmount != 0) {
        addAmountRow('VAT', vatAmount);
      }
    }
    addAmountRow('TOTAL', total);

    final payments = (orderData['payments'] as List<dynamic>? ?? <dynamic>[]);
    if (payments.isNotEmpty) {
      bytes.addAll(
        generator.text('Payments', styles: const PosStyles(bold: true)),
      );
      for (final raw in payments) {
        final payment = raw as Map<String, dynamic>? ?? <String, dynamic>{};
        final method = payment['method']?.toString() ?? 'Payment';
        final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
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
