// lib/receipt_page.dart (Updated)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
class ReceiptPage {
  final Map<String, dynamic> orderData;

  ReceiptPage({required this.orderData});

  Future<void> printReceipt() async {
    final doc = pw.Document();

    final fontData = await rootBundle.load("google_fonts/Sarabun-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          final List<dynamic> items = orderData['items'] ?? [];
          final Timestamp timestamp = orderData['timestamp'];
          final String formattedDate = DateFormat(
            'dd/MM/yyyy, HH:mm',
          ).format(timestamp.toDate());

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'ใบเสร็จรับเงิน',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 15),
              pw.Text(
                'Order: ${orderData['orderIdentifier'] ?? 'N/A'}',
                style: pw.TextStyle(font: ttf, fontSize: 12),
              ),
              pw.Text(
                'Date: $formattedDate',
                style: pw.TextStyle(font: ttf, fontSize: 12),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Divider(),
              ),

              // New, updated way to build a table
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1.5),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Item',
                          style: pw.TextStyle(
                            font: ttf,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Qty',
                          style: pw.TextStyle(
                            font: ttf,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Price',
                          style: pw.TextStyle(
                            font: ttf,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Table Rows for each item
                  ...items.map((item) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            item['name'],
                            style: pw.TextStyle(font: ttf),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            item['quantity'].toString(),
                            style: pw.TextStyle(font: ttf),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            (item['price'] as num).toStringAsFixed(2),
                            style: pw.TextStyle(font: ttf),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Divider(),
              ),

              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Total: ${(orderData['total'] ?? 0 as num).toStringAsFixed(2)} บาท',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }
}
