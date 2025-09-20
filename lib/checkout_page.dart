// lib/checkout_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'services/printing_service.dart';
import 'stock_provider.dart';

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
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final PrintingService _printingService = PrintingService();
  bool _isConfirming = false;

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
      await _printingService.previewReceipt(orderDoc.data()!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Preview Error: $e')));
    }
  }

  Future<void> _confirmPayment() async {
    setState(() {
      _isConfirming = true;
    });

    final orderRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId);

    final payload = <String, dynamic>{
      'status': 'completed',
      'completedAt': Timestamp.now(),
      'paidTotal': widget.totalAmount,
      'serviceChargeAmount': widget.serviceChargeAmount,
      'serviceChargeRate': widget.serviceChargeRate,
      'tipAmount': widget.tipAmount,
      'splitCount': widget.splitCount,
      'splitAmountPerGuest':
          widget.splitAmountPerGuest ??
          (widget.splitCount <= 0
              ? widget.totalAmount
              : widget.totalAmount / widget.splitCount),
    };

    try {
      await orderRef.update(payload);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment confirmed successfully!')),
      );
      context.go('/order-type-selection');
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
