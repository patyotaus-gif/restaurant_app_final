// lib/checkout_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'models/receipt_models.dart';
import 'services/payment_gateway_service.dart';
import 'services/printer_drawer_service.dart';
import 'services/printing_service.dart';
import 'services/receipt_service.dart';
import 'stock_provider.dart';
import 'store_provider.dart';

class CheckoutPage extends StatefulWidget {
  final String orderId;
  final double totalAmount;
  final String orderIdentifier;
  final double subtotal;
  final double discountAmount;
  final double serviceChargeAmount;
  final double serviceChargeRate;
  final double tipAmount;
  final int splitCount;
  final double? splitAmountPerGuest;
  final double giftCardAmount;
  final double storeCreditAmount;
  final double amountDueAfterCredits;
  final List<Map<String, dynamic>> payments;

  const CheckoutPage({
    super.key,
    required this.orderId,
    required this.totalAmount,
    required this.orderIdentifier,
    this.subtotal = 0,
    this.discountAmount = 0,
    this.serviceChargeAmount = 0,
    this.serviceChargeRate = 0,
    this.tipAmount = 0,
    this.splitCount = 1,
    this.splitAmountPerGuest,
    this.giftCardAmount = 0,
    this.storeCreditAmount = 0,
    this.amountDueAfterCredits = 0,
    this.payments = const [],
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final PrintingService _printingService = PrintingService();
  final ReceiptService _receiptService = ReceiptService();
  bool _isConfirming = false;
  bool _includeTaxInvoice = false;
  bool _sendEmailReceipt = false;
  bool _isGeneratingReceipt = false;
  String? _generatedReceiptUrl;
  late final TextEditingController _printerIpController;
  late final TextEditingController _printerPortController;
  bool _openDrawerAfterPrint = true;
  bool _isPrintingEscPos = false;

  final _customerNameController = TextEditingController();
  final _customerTaxIdController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _printerIpController = TextEditingController();
    _printerPortController = TextEditingController(text: '9100');
  }

  String _formatNumber(double value) {
    var text = value.toStringAsFixed(2);
    if (!text.contains('.')) return text;
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.endsWith('.')) {
      text = text.substring(0, text.length - 1);
    }
    return text;
  }

  Widget _buildSummaryRow(
    String label,
    double amount, {
    bool isTotal = false,
    Color? valueColor,
  }) {
    final baseStyle = TextStyle(
      fontSize: isTotal ? 18 : 16,
      fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
    );
    final colorStyle = valueColor != null
        ? baseStyle.copyWith(color: valueColor)
        : baseStyle;
    final formatted =
        '${amount < 0 ? '- ' : ''}${amount.abs().toStringAsFixed(2)} บาท';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: baseStyle),
          Text(formatted, style: colorStyle),
        ],
      ),
    );
  }

  Widget _buildAmountBreakdown() {
    final effectiveSubtotal = widget.subtotal > 0
        ? widget.subtotal
        : (widget.totalAmount > 0 &&
              widget.discountAmount == 0 &&
              widget.serviceChargeAmount == 0 &&
              widget.tipAmount == 0)
        ? widget.totalAmount
        : widget.subtotal;

    final rows = <Widget>[_buildSummaryRow('Subtotal', effectiveSubtotal)];

    if (widget.discountAmount > 0) {
      rows.add(
        _buildSummaryRow(
          'Discount',
          -widget.discountAmount,
          valueColor: Colors.red.shade700,
        ),
      );
    }

    if (widget.serviceChargeAmount > 0) {
      final percentText = widget.serviceChargeRate > 0
          ? ' (${_formatNumber(widget.serviceChargeRate * 100)}%)'
          : '';
      rows.add(
        _buildSummaryRow(
          'Service Charge$percentText',
          widget.serviceChargeAmount,
          valueColor: Colors.orange.shade700,
        ),
      );
    }

    if (widget.tipAmount > 0) {
      rows.add(
        _buildSummaryRow(
          'Tip',
          widget.tipAmount,
          valueColor: Colors.orange.shade700,
        ),
      );
    }

    rows.add(const Divider());
    rows.add(
      _buildSummaryRow(
        'Total Due',
        widget.totalAmount,
        isTotal: true,
        valueColor: Colors.green.shade700,
      ),
    );

    if (widget.giftCardAmount > 0 || widget.storeCreditAmount > 0) {
      rows.add(const Divider());
      if (widget.giftCardAmount > 0) {
        rows.add(
          _buildSummaryRow(
            'Gift Card Applied',
            -widget.giftCardAmount,
            valueColor: Colors.purple.shade700,
          ),
        );
      }
      if (widget.storeCreditAmount > 0) {
        rows.add(
          _buildSummaryRow(
            'Store Credit Applied',
            -widget.storeCreditAmount,
            valueColor: Colors.blue.shade700,
          ),
        );
      }
      rows.add(
        _buildSummaryRow(
          'Amount Remaining',
          widget.amountDueAfterCredits,
          isTotal: true,
          valueColor: widget.amountDueAfterCredits == 0
              ? Colors.green.shade700
              : Colors.deepPurple,
        ),
      );
    }

    if (widget.splitCount > 1) {
      final perGuest =
          widget.splitAmountPerGuest ??
          (widget.splitCount <= 0
              ? widget.totalAmount
              : widget.totalAmount / widget.splitCount);
      rows.add(const SizedBox(height: 8));
      rows.add(
        Text(
          'Split between ${widget.splitCount} guests: ${perGuest.toStringAsFixed(2)} บาท each',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        ),
      ),
    );
  }

  Widget _buildDigitalReceiptCard() {
    final labelStyle =
        Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold) ??
        const TextStyle(fontSize: 18, fontWeight: FontWeight.bold);

    final helperStyle = Theme.of(context).textTheme.bodySmall;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PDF & e-Receipt Options', style: labelStyle),
            if (helperStyle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'สร้างใบเสร็จในรูปแบบ PDF, พร้อมข้อมูลใบกำกับภาษี และส่งให้ลูกค้าผ่านอีเมลหรือ QR code',
                  style: helperStyle,
                ),
              ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Include Tax Invoice Details'),
              subtitle: const Text('ระบุข้อมูลสำหรับออกใบกำกับภาษีเต็มรูปแบบ'),
              value: _includeTaxInvoice,
              onChanged: (value) {
                setState(() {
                  _includeTaxInvoice = value;
                });
              },
            ),
            if (_includeTaxInvoice) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customerNameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อลูกค้า / บริษัท',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customerTaxIdController,
                decoration: const InputDecoration(
                  labelText: 'เลขประจำตัวผู้เสียภาษี',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customerAddressController,
                decoration: const InputDecoration(
                  labelText: 'ที่อยู่สำหรับใบกำกับภาษี',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customerPhoneController,
                decoration: const InputDecoration(
                  labelText: 'เบอร์ติดต่อ (ถ้ามี)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
            ],
            SwitchListTile(
              title: const Text('Send e-Receipt via Email'),
              subtitle: const Text('ส่งไฟล์ PDF และลิงก์ผ่านอีเมลให้ลูกค้า'),
              value: _sendEmailReceipt,
              onChanged: (value) {
                setState(() {
                  _sendEmailReceipt = value;
                });
              },
            ),
            if (_sendEmailReceipt) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customerEmailController,
                decoration: const InputDecoration(
                  labelText: 'อีเมลลูกค้า',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGeneratingReceipt
                    ? null
                    : _generateDigitalReceipt,
                icon: _isGeneratingReceipt
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(
                  _sendEmailReceipt
                      ? 'สร้าง PDF & ส่ง e-Receipt'
                      : 'สร้าง PDF ใบเสร็จ',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_generatedReceiptUrl != null) ...[
              const Divider(height: 32),
              Text(
                'QR สำหรับ e-Receipt',
                style: labelStyle.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Center(
                child: QrImageView(
                  data: _generatedReceiptUrl!,
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                _generatedReceiptUrl!,
                style: const TextStyle(fontSize: 12),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: _generatedReceiptUrl!),
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('คัดลอกลิงก์เรียบร้อยแล้ว')),
                    );
                  },
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('คัดลอกลิงก์'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExistingPaymentsCard() {
    if (widget.payments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Applied Payments',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...widget.payments.map((payment) {
              final method = payment['method']?.toString() ?? 'Unknown';
              final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
              final reference = payment['reference']?.toString();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.payments, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            method,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${amount.toStringAsFixed(2)} บาท',
                            style: const TextStyle(color: Colors.green),
                          ),
                          if (reference != null && reference.isNotEmpty)
                            Text(
                              'Ref: $reference',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _generatePromptPayPayload(double amount) {
    const promptPayId = '0812345678';
    return 'promptpay-qr-code-payload-for-$promptPayId-with-amount-$amount';
  }

  Future<void> _handleReceiptPreview() async {
    try {
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();
      if (!orderDoc.exists) {
        throw Exception('Order not found!');
      }
      final store = context.read<StoreProvider>().activeStore;
      if (store == null) {
        throw Exception('Store information not available');
      }
      await _printingService.previewReceipt(
        orderDoc.data()!,
        storeDetails: StoreReceiptDetails.fromStore(store),
        taxDetails: _includeTaxInvoice
            ? TaxInvoiceDetails(
                customerName: _customerNameController.text.trim(),
                taxId: _customerTaxIdController.text.trim(),
                address: _customerAddressController.text.trim(),
                email: _customerEmailController.text.trim(),
                phone: _customerPhoneController.text.trim(),
              )
            : null,
        includeTaxInvoice: _includeTaxInvoice,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Preview Error: $e')));
    }
  }

  bool _isValidEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return false;
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }

  TaxInvoiceDetails? _buildTaxInvoiceDetails() {
    if (!_includeTaxInvoice) return null;
    return TaxInvoiceDetails(
      customerName: _customerNameController.text.trim(),
      taxId: _customerTaxIdController.text.trim(),
      address: _customerAddressController.text.trim(),
      email: _customerEmailController.text.trim(),
      phone: _customerPhoneController.text.trim(),
    );
  }

  Future<void> _generateDigitalReceipt() async {
    if (_includeTaxInvoice && _customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อสำหรับใบกำกับภาษี')),
      );
      return;
    }

    if (_sendEmailReceipt && !_isValidEmail(_customerEmailController.text)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกอีเมลให้ถูกต้อง')));
      return;
    }

    setState(() {
      _isGeneratingReceipt = true;
      _generatedReceiptUrl = null;
    });

    try {
      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId);
      final orderSnapshot = await orderRef.get();
      final orderData = orderSnapshot.data();
      if (orderData == null) {
        throw Exception('Order not found');
      }

      final store = context.read<StoreProvider>().activeStore;
      if (store == null) {
        throw Exception('Store information not available');
      }

      final taxDetails = _buildTaxInvoiceDetails();
      final receiptUrl = await _receiptService.generateAndDistributeReceipt(
        orderId: widget.orderId,
        orderData: orderData,
        storeDetails: StoreReceiptDetails.fromStore(store),
        taxDetails: taxDetails,
        includeTaxInvoice: _includeTaxInvoice,
        recipientEmail: _sendEmailReceipt
            ? _customerEmailController.text.trim()
            : null,
      );

      await _receiptService.persistReceiptMetadata(
        orderId: widget.orderId,
        receiptUrl: receiptUrl,
        recipientEmail: _sendEmailReceipt
            ? _customerEmailController.text.trim()
            : null,
        taxDetails: taxDetails,
        includeTaxInvoice: _includeTaxInvoice,
      );

      setState(() {
        _generatedReceiptUrl = receiptUrl;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _sendEmailReceipt
                ? 'ส่ง e-Receipt ไปยังอีเมลเรียบร้อยแล้ว'
                : 'สร้าง PDF เรียบร้อยแล้ว',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ไม่สามารถสร้างใบเสร็จได้: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingReceipt = false;
        });
      }
    }
  }

  Future<void> _confirmPayment() async {
    setState(() {
      _isConfirming = true;
    });

    final outstanding = widget.amountDueAfterCredits <= 0
        ? 0.0
        : widget.amountDueAfterCredits;
    final orderRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId);

    if (outstanding == 0) {
      try {
        await orderRef.update({
          'status': 'completed',
          'completedAt': Timestamp.now(),
          'paidTotal': widget.totalAmount,
          'paymentStatus': 'paid',
        });
        await _handlePostPaymentSuccess(
          orderRef,
          successMessage: 'Order settled using credits and gift cards.',
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to finalize order: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isConfirming = false;
          });
        }
      }
      return;
    }

    final gatewayService = context.read<PaymentGatewayService>();
    final paymentRequest = PaymentRequest(
      amount: outstanding,
      currency: 'THB',
      orderId: widget.orderId,
      description: 'Order ${widget.orderIdentifier}',
      metadata: {
        'orderIdentifier': widget.orderIdentifier,
        'subtotal': widget.subtotal,
        'discount': widget.discountAmount,
        'serviceCharge': widget.serviceChargeAmount,
        'tip': widget.tipAmount,
        'splitCount': widget.splitCount,
      },
      customerEmail: _customerEmailController.text.trim().isEmpty
          ? null
          : _customerEmailController.text.trim(),
      customerName: _customerNameController.text.trim().isEmpty
          ? null
          : _customerNameController.text.trim(),
    );

    PaymentResult paymentResult;
    try {
      paymentResult = await gatewayService.processPayment(paymentRequest);
    } on PaymentGatewayException catch (e) {
      if (!mounted) return;
      setState(() {
        _isConfirming = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Payment failed: ${e.message}')));
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConfirming = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
      return;
    }

    final payload = <String, dynamic>{
      'status': 'completed',
      'completedAt': Timestamp.now(),
      'paidTotal': widget.totalAmount,
      'paymentStatus': 'paid',
      'serviceChargeAmount': widget.serviceChargeAmount,
      'serviceChargeRate': widget.serviceChargeRate,
      'tipAmount': widget.tipAmount,
      'splitCount': widget.splitCount,
      'splitAmountPerGuest':
          widget.splitAmountPerGuest ??
          (widget.splitCount <= 0
              ? widget.totalAmount
              : widget.totalAmount / widget.splitCount),
      'paymentGateway': gatewayService.activeGateway.name,
      'paymentTransactionId': paymentResult.transactionId,
      if (paymentResult.receiptUrl != null)
        'paymentReceiptUrl': paymentResult.receiptUrl,
      if (paymentResult.metadata.isNotEmpty)
        'paymentGatewayMetadata': paymentResult.metadata,
      'payments': FieldValue.arrayUnion([
        {
          'method': PaymentGatewayService.describeGateway(
            gatewayService.activeGateway,
          ),
          'amount': outstanding,
          'currency': 'THB',
          'transactionId': paymentResult.transactionId,
          'processedAt': Timestamp.now(),
        },
      ]),
    };

    try {
      await orderRef.update(payload);
      await _handlePostPaymentSuccess(
        orderRef,
        successMessage: 'Payment confirmed successfully!',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to confirm payment: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isConfirming = false;
        });
      }
    }
  }

  String _maskCredential(String? value) {
    if (value == null || value.isEmpty) {
      return 'Not configured';
    }
    final visible = value.length <= 4
        ? value
        : value.substring(value.length - 4);
    return '****$visible';
  }

  Widget _buildPaymentGatewayCard() {
    final paymentService = context.watch<PaymentGatewayService>();
    final labelStyle =
        Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold) ??
        const TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
    final helperStyle = Theme.of(context).textTheme.bodySmall;
    final config = paymentService.activeConfig;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment Gateway', style: labelStyle),
            if (helperStyle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Text(
                  'เลือกผู้ให้บริการสำหรับประมวลผลการชำระเงินออนไลน์ได้ทันที',
                  style: helperStyle,
                ),
              ),
            DropdownButtonFormField<PaymentGatewayType>(
              value: paymentService.activeGateway,
              decoration: const InputDecoration(
                labelText: 'Active Gateway',
                border: OutlineInputBorder(),
              ),
              items: paymentService.supportedGateways
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(PaymentGatewayService.describeGateway(type)),
                    ),
                  )
                  .toList(),
              onChanged: (type) {
                if (type != null) {
                  paymentService.switchGateway(type);
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Adapter: ${PaymentGatewayService.describeGateway(paymentService.activeGateway)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (config != null && config.merchantAccount != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Merchant: ${config.merchantAccount}'),
              ),
            if (config != null && config.apiKey != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('API Key: ${_maskCredential(config.apiKey)}'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrinterCard() {
    final labelStyle =
        Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold) ??
        const TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
    final helperStyle = Theme.of(context).textTheme.bodySmall;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thermal Printer & Cash Drawer', style: labelStyle),
            if (helperStyle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Text(
                  'พิมพ์ใบเสร็จผ่านเครื่อง ESC/POS ที่เชื่อมต่อผ่าน TCP และสั่งเปิดลิ้นชักเงินสดอัตโนมัติ',
                  style: helperStyle,
                ),
              ),
            TextField(
              controller: _printerIpController,
              decoration: const InputDecoration(
                labelText: 'Printer IP Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.print),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _printerPortController,
              decoration: const InputDecoration(
                labelText: 'Port',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('เปิดลิ้นชักเงินสดหลังพิมพ์'),
              value: _openDrawerAfterPrint,
              onChanged: (value) {
                setState(() {
                  _openDrawerAfterPrint = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printViaEscPos() async {
    final printerIp = _printerIpController.text.trim();
    final printerPort = int.tryParse(_printerPortController.text.trim());

    if (printerIp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาระบุ IP Address ของเครื่องพิมพ์')),
      );
      return;
    }

    setState(() {
      _isPrintingEscPos = true;
    });

    try {
      final orderSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();
      final orderData = orderSnapshot.data();
      if (orderData == null) {
        throw Exception('Order not found');
      }

      final store = context.read<StoreProvider>().activeStore;
      if (store == null) {
        throw Exception('Store information not available');
      }

      final printerService = context.read<PrinterDrawerService>();
      await printerService.printReceipt(
        host: printerIp,
        port: printerPort ?? 9100,
        orderData: orderData,
        storeDetails: StoreReceiptDetails.fromStore(store),
        taxDetails: _buildTaxInvoiceDetails(),
      );

      if (_openDrawerAfterPrint) {
        await printerService.openCashDrawer(
          host: printerIp,
          port: printerPort ?? 9100,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'สั่งพิมพ์ใบเสร็จผ่านเครื่องพิมพ์ความร้อนเรียบร้อยแล้ว',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ไม่สามารถสั่งพิมพ์ได้: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isPrintingEscPos = false;
        });
      }
    }
  }

  Future<void> _handlePostPaymentSuccess(
    DocumentReference<Map<String, dynamic>> orderRef, {
    required String successMessage,
  }) async {
    final orderSnapshot = await orderRef.get();
    final data = orderSnapshot.data();

    if (data != null) {
      final usage = (data['ingredientUsage'] as List<dynamic>?) ?? [];
      final stockDeducted = data['stockDeducted'] == true;

      if (usage.isNotEmpty && !stockDeducted) {
        try {
          final stockProvider = Provider.of<StockProvider>(
            context,
            listen: false,
          );
          await stockProvider.deductIngredientsFromUsage(usage);
          await orderRef.update({'stockDeducted': true});
        } catch (e) {
          // If stock provider isn't available, skip deduction but do not fail.
        }
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successMessage)));
    context.go('/order-type-selection');
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerTaxIdController.dispose();
    _customerAddressController.dispose();
    _customerEmailController.dispose();
    _customerPhoneController.dispose();
    _printerIpController.dispose();
    _printerPortController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qrData = _generatePromptPayPayload(widget.totalAmount);

    return Scaffold(
      appBar: AppBar(
        title: Text('Checkout • ${widget.orderIdentifier}'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Scan to Pay',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 8,
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 250.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'Total Amount: ${widget.totalAmount.toStringAsFixed(2)} บาท',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildAmountBreakdown(),
              _buildExistingPaymentsCard(),
              _buildPaymentGatewayCard(),
              _buildDigitalReceiptCard(),
              _buildPrinterCard(),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.visibility),
                    label: const Text('Preview Receipt (PDF)'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    onPressed: _handleReceiptPreview,
                  ),
                  OutlinedButton.icon(
                    icon: _isPrintingEscPos
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print),
                    label: const Text('Print to ESC/POS'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    onPressed: _isPrintingEscPos ? null : _printViaEscPos,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: _isConfirming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle),
                label: const Text('Confirm Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _isConfirming ? null : _confirmPayment,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
