import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/receipt_models.dart';

class PrintingService {
  Future<void> previewReceipt(
    Map<String, dynamic> orderData, {
    required StoreReceiptDetails storeDetails,
    TaxInvoiceDetails? taxDetails,
    bool includeTaxInvoice = false,
  }) async {
    final pdfBytes = await buildReceiptPdf(
      orderData,
      storeDetails: storeDetails,
      taxDetails: taxDetails,
      includeTaxInvoice: includeTaxInvoice,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  Future<Uint8List> buildReceiptPdf(
    Map<String, dynamic> orderData, {
    required StoreReceiptDetails storeDetails,
    TaxInvoiceDetails? taxDetails,
    bool includeTaxInvoice = false,
  }) async {
    final doc = pw.Document();

    final fontData = await rootBundle.load('google_fonts/Sarabun-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);

    final List<dynamic> items = List<dynamic>.from(orderData['items'] ?? []);
    final Timestamp? timestamp = orderData['timestamp'] as Timestamp?;
    final DateTime orderDate = (timestamp?.toDate() ?? DateTime.now())
        .toLocal();
    final String formattedDate = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(orderDate);
    final String orderIdentifier =
        orderData['orderIdentifier'] as String? ?? 'N/A';

    final num subtotal = orderData['subtotal'] as num? ?? 0;
    final num discount = orderData['discount'] as num? ?? 0;
    final num serviceCharge = orderData['serviceChargeAmount'] as num? ?? 0;
    final num tip = orderData['tipAmount'] as num? ?? 0;
    final num total = orderData['total'] as num? ?? subtotal;

    final Map<String, dynamic>? taxData =
        orderData['tax'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(orderData['tax'] as Map<String, dynamic>)
        : null;
    final List<MapEntry<String, double>> taxLines = [];
    double taxRounding = 0;
    if (taxData != null) {
      final List<dynamic>? rawLines = taxData['lines'] as List<dynamic>?;
      if (rawLines != null) {
        for (final raw in rawLines) {
          if (raw is Map<String, dynamic>) {
            final name = raw['name']?.toString() ?? 'Tax';
            final amount = (raw['amount'] as num?)?.toDouble() ?? 0.0;
            taxLines.add(MapEntry(name, amount));
          }
        }
      }
      taxRounding = (taxData['roundingDelta'] as num?)?.toDouble() ?? 0.0;
      if (taxLines.isEmpty) {
        final totalTax = (taxData['total'] as num?)?.toDouble() ?? 0.0;
        if (totalTax > 0) {
          taxLines.add(MapEntry('Tax', totalTax));
        }
      }
    } else if (orderData['vat'] is Map<String, dynamic>) {
      final vatData = orderData['vat'] as Map<String, dynamic>;
      final num vatRate = vatData['rate'] as num? ?? 0;
      final double vatAmount = (vatData['amount'] as num?)?.toDouble() ?? 0.0;
      final label = vatRate > 0
          ? 'VAT (${(vatRate * 100).toStringAsFixed(0)}%)'
          : 'VAT';
      taxLines.add(MapEntry(label, vatAmount));
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildStoreHeader(ttf, storeDetails),
                pw.SizedBox(height: 12),
                pw.Text(
                  includeTaxInvoice ? 'TAX INVOICE / RECEIPT' : 'RECEIPT',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                _buildOrderMeta(ttf, orderIdentifier, formattedDate, orderData),
                if (taxDetails != null &&
                    (includeTaxInvoice || taxDetails.hasData)) ...[
                  pw.SizedBox(height: 12),
                  _buildCustomerSection(ttf, taxDetails),
                ],
                pw.SizedBox(height: 16),
                _buildItemsTable(ttf, items),
                pw.SizedBox(height: 12),
                _buildTotals(
                  ttf,
                  subtotal: subtotal,
                  discount: discount,
                  serviceCharge: serviceCharge,
                  tip: tip,
                  taxLines: taxLines,
                  taxRounding: taxRounding,
                  total: total,
                ),
                pw.SizedBox(height: 24),
                _buildPaymentSummary(ttf, orderData),
                if (includeTaxInvoice)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 24),
                    child: pw.Text(
                      'This document serves as an official tax invoice pursuant to Thai Revenue Code.',
                      style: pw.TextStyle(font: ttf, fontSize: 10),
                    ),
                  ),
                pw.SizedBox(height: 24),
                pw.Text(
                  'Thank you for dining with us!',
                  style: pw.TextStyle(font: ttf, fontSize: 12),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return Uint8List.fromList(await doc.save());
  }

  pw.Widget _buildStoreHeader(pw.Font ttf, StoreReceiptDetails details) {
    final lines = <String>[details.name];
    if (details.branch != null && details.branch!.isNotEmpty) {
      lines.add('Branch: ${details.branch}');
    }
    if (details.address != null && details.address!.isNotEmpty) {
      lines.add(details.address!);
    }
    if (details.taxId != null && details.taxId!.isNotEmpty) {
      lines.add('Tax ID: ${details.taxId}');
    }
    if (details.phone != null && details.phone!.isNotEmpty) {
      lines.add('Tel: ${details.phone}');
    }
    if (details.email != null && details.email!.isNotEmpty) {
      lines.add('Email: ${details.email}');
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          pw.Text(line, style: pw.TextStyle(font: ttf, fontSize: 12)),
      ],
    );
  }

  pw.Widget _buildOrderMeta(
    pw.Font ttf,
    String orderIdentifier,
    String formattedDate,
    Map<String, dynamic> orderData,
  ) {
    final meta = <String>['Order: $orderIdentifier', 'Date: $formattedDate'];

    if (orderData['paymentMethod'] != null) {
      meta.add('Payment Method: ${orderData['paymentMethod']}');
    }
    if (orderData['cashier'] != null) {
      meta.add('Processed By: ${orderData['cashier']}');
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final line in meta)
          pw.Text(line, style: pw.TextStyle(font: ttf, fontSize: 11)),
      ],
    );
  }

  pw.Widget _buildCustomerSection(pw.Font ttf, TaxInvoiceDetails details) {
    final rows = <pw.Widget>[];
    if (details.customerName != null && details.customerName!.isNotEmpty) {
      rows.add(_buildMetaRow(ttf, 'Customer Name', details.customerName!));
    }
    if (details.taxId != null && details.taxId!.isNotEmpty) {
      rows.add(_buildMetaRow(ttf, 'Tax ID', details.taxId!));
    }
    if (details.address != null && details.address!.isNotEmpty) {
      rows.add(_buildMetaRow(ttf, 'Address', details.address!));
    }
    if (details.phone != null && details.phone!.isNotEmpty) {
      rows.add(_buildMetaRow(ttf, 'Phone', details.phone!));
    }
    if (details.email != null && details.email!.isNotEmpty) {
      rows.add(_buildMetaRow(ttf, 'Email', details.email!));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Bill To',
          style: pw.TextStyle(
            font: ttf,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        ...rows,
      ],
    );
  }

  pw.Widget _buildMetaRow(pw.Font ttf, String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(
                font: ttf,
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
              ),
            ),
            pw.TextSpan(
              text: value,
              style: pw.TextStyle(font: ttf, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildItemsTable(pw.Font ttf, List<dynamic> items) {
    final headers = ['Item', 'Qty', 'Unit Price', 'Total'];
    final dataRows = items.map((item) {
      final qty = (item['quantity'] as num?) ?? 0;
      final price = (item['price'] as num?) ?? 0;
      final total = qty * price;
      return [
        item['name'] ?? '',
        qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2),
        price.toStringAsFixed(2),
        total.toStringAsFixed(2),
      ];
    }).toList();

    return pw.Table.fromTextArray(
      headers: headers,
      data: dataRows,
      headerStyle: pw.TextStyle(
        font: ttf,
        fontWeight: pw.FontWeight.bold,
        fontSize: 11,
      ),
      cellStyle: pw.TextStyle(font: ttf, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
    );
  }

  pw.Widget _buildTotals(
    pw.Font ttf, {
    required num subtotal,
    required num discount,
    required num serviceCharge,
    required num tip,
    required List<MapEntry<String, double>> taxLines,
    required num taxRounding,
    required num total,
  }) {
    final rows = <pw.Widget>[];

    rows.add(_buildTotalRow(ttf, 'Subtotal', subtotal));
    if (discount > 0) {
      rows.add(_buildTotalRow(ttf, 'Discount', -discount));
    }
    if (serviceCharge > 0) {
      rows.add(_buildTotalRow(ttf, 'Service Charge', serviceCharge));
    }
    if (tip > 0) {
      rows.add(_buildTotalRow(ttf, 'Tip', tip));
    }
    if (taxLines.isNotEmpty) {
      final double aggregatedTax = taxLines.fold<double>(
        0,
        (sum, line) => sum + line.value,
      );
      rows.add(_buildTotalRow(ttf, 'Tax', aggregatedTax));
      for (final tax in taxLines) {
        rows.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 12),
            child: _buildTotalRow(ttf, tax.key, tax.value),
          ),
        );
      }
      if (taxRounding != 0) {
        rows.add(_buildTotalRow(ttf, 'Tax Rounding', taxRounding));
      }
    }

    rows.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4),
        child: _buildTotalRow(ttf, 'Total', total, isGrandTotal: true),
      ),
    );

    return pw.Column(children: rows);
  }

  pw.Widget _buildTotalRow(
    pw.Font ttf,
    String label,
    num amount, {
    bool isGrandTotal = false,
  }) {
    final style = pw.TextStyle(
      font: ttf,
      fontSize: isGrandTotal ? 14 : 11,
      fontWeight: isGrandTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(
          '${amount < 0 ? '-' : ''}${amount.abs().toStringAsFixed(2)}',
          style: style,
        ),
      ],
    );
  }

  pw.Widget _buildPaymentSummary(pw.Font ttf, Map<String, dynamic> orderData) {
    final payments = orderData['payments'] as List<dynamic>?;
    if (payments == null || payments.isEmpty) {
      return pw.SizedBox.shrink();
    }

    final rows = payments.map((payment) {
      final method = payment['method'] ?? 'Payment';
      final amount = (payment['amount'] as num?) ?? 0;
      return _buildMetaRow(ttf, method.toString(), amount.toStringAsFixed(2));
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Payment Summary',
          style: pw.TextStyle(
            font: ttf,
            fontWeight: pw.FontWeight.bold,
            fontSize: 12,
          ),
        ),
        pw.SizedBox(height: 4),
        ...rows,
      ],
    );
  }
}
