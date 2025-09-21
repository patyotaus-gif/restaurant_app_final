import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/receipt_models.dart';
import 'printing_service.dart';

class ReceiptService {
  ReceiptService({
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
    PrintingService? printingService,
  }) : _storage = storage ?? FirebaseStorage.instance,
       _functions = functions ?? FirebaseFunctions.instance,
       _printingService = printingService ?? PrintingService();

  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;
  final PrintingService _printingService;

  Future<Uint8List> buildReceiptPdf({
    required Map<String, dynamic> orderData,
    required StoreReceiptDetails storeDetails,
    TaxInvoiceDetails? taxDetails,
    bool includeTaxInvoice = false,
  }) {
    return _printingService.buildReceiptPdf(
      orderData,
      storeDetails: storeDetails,
      taxDetails: taxDetails,
      includeTaxInvoice: includeTaxInvoice,
    );
  }

  Future<String> uploadReceiptPdf({
    required String orderId,
    required Uint8List pdfBytes,
    String? fileName,
  }) async {
    final safeName = fileName ?? 'receipt-$orderId.pdf';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage
        .ref()
        .child('receipts')
        .child(orderId)
        .child('$timestamp-$safeName');

    final metadata = SettableMetadata(contentType: 'application/pdf');
    await ref.putData(pdfBytes, metadata);
    return ref.getDownloadURL();
  }

  Future<void> sendReceiptEmail({
    required String orderId,
    required Map<String, dynamic> orderData,
    required StoreReceiptDetails storeDetails,
    required String recipientEmail,
    required String receiptUrl,
    Uint8List? pdfBytes,
    TaxInvoiceDetails? taxDetails,
  }) async {
    final callable = _functions.httpsCallable('sendReceiptEmail');

    final num total = orderData['total'] as num? ?? 0;
    final String orderIdentifier =
        orderData['orderIdentifier'] as String? ?? orderId;

    await callable.call({
      'email': recipientEmail,
      'orderId': orderId,
      'orderIdentifier': orderIdentifier,
      'total': total.toDouble(),
      'receiptUrl': receiptUrl,
      'store': storeDetails.toMap(),
      'customer': taxDetails?.toMap(),
      if (pdfBytes != null) 'pdfBase64': base64Encode(pdfBytes),
    });
  }

  Future<String> generateAndDistributeReceipt({
    required String orderId,
    required Map<String, dynamic> orderData,
    required StoreReceiptDetails storeDetails,
    TaxInvoiceDetails? taxDetails,
    bool includeTaxInvoice = false,
    String? recipientEmail,
  }) async {
    final pdfBytes = await buildReceiptPdf(
      orderData: orderData,
      storeDetails: storeDetails,
      taxDetails: taxDetails,
      includeTaxInvoice: includeTaxInvoice,
    );

    final downloadUrl = await uploadReceiptPdf(
      orderId: orderId,
      pdfBytes: pdfBytes,
    );

    if (recipientEmail != null && recipientEmail.isNotEmpty) {
      await sendReceiptEmail(
        orderId: orderId,
        orderData: orderData,
        storeDetails: storeDetails,
        recipientEmail: recipientEmail,
        receiptUrl: downloadUrl,
        pdfBytes: pdfBytes,
        taxDetails: taxDetails,
      );
    }

    return downloadUrl;
  }

  Future<void> persistReceiptMetadata({
    required String orderId,
    required String receiptUrl,
    String? recipientEmail,
    TaxInvoiceDetails? taxDetails,
    bool includeTaxInvoice = false,
  }) async {
    final receiptData = <String, dynamic>{
      'url': receiptUrl,
      if (recipientEmail != null && recipientEmail.isNotEmpty)
        'email': recipientEmail,
      'generatedAt': Timestamp.now(),
      'includeTaxInvoice': includeTaxInvoice,
      if (taxDetails != null && taxDetails.hasData)
        'taxInvoice': taxDetails.toMap(),
    };

    await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
      'receiptInfo': receiptData,
    }, SetOptions(merge: true));
  }
}
