import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PdfReceiptPage extends StatelessWidget {
  final Map<String, dynamic> orderData;

  const PdfReceiptPage({super.key, required this.orderData});

  Future<Uint8List> _buildReceiptPdf(PdfPageFormat format) async {
    final doc = pw.Document();

    final fontData = await rootBundle.load("google_fonts/Sarabun-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    final List<dynamic> items = orderData['items'] ?? [];
    final Timestamp timestamp = orderData['timestamp'];
    final String formattedDate = DateFormat(
      'dd/MM/yyyy, HH:mm',
    ).format(timestamp.toDate());

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'RECEIPT',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Order: ${orderData['orderIdentifier'] ?? 'N/A'}',
                style: pw.TextStyle(font: ttf),
              ),
              pw.Text('Date: $formattedDate', style: pw.TextStyle(font: ttf)),
              pw.Divider(height: 16),

              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 7,
                    child: pw.Text(
                      'Item',
                      style: pw.TextStyle(
                        font: ttf,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Qty',
                      style: pw.TextStyle(
                        font: ttf,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      'Price',
                      style: pw.TextStyle(
                        font: ttf,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.Divider(),

              ...items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 7,
                        child: pw.Text(
                          '${item['name']}',
                          style: pw.TextStyle(font: ttf),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          item['quantity'].toString(),
                          style: pw.TextStyle(font: ttf),
                        ),
                      ),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          (item['price'] as num).toStringAsFixed(2),
                          style: pw.TextStyle(font: ttf),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.Divider(height: 16),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal', style: pw.TextStyle(font: ttf)),
                  pw.Text(
                    (orderData['subtotal'] as num? ?? 0.0).toStringAsFixed(2),
                    style: pw.TextStyle(font: ttf),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Discount', style: pw.TextStyle(font: ttf)),
                  pw.Text(
                    (orderData['discount'] as num? ?? 0.0).toStringAsFixed(2),
                    style: pw.TextStyle(font: ttf),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    (orderData['total'] as num).toStringAsFixed(2),
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text('Thank You!', style: pw.TextStyle(font: ttf)),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Preview')),
      body: PdfPreview(
        build: _buildReceiptPdf,
        useActions: true, // Show share, print, and save buttons
      ),
    );
  }
}
