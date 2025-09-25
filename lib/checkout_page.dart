// lib/checkout_page.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:restaurant_models/restaurant_models.dart';

import 'currency_provider.dart';
import 'locale_provider.dart';
import 'services/house_account_service.dart';
import 'services/payment_gateway_service.dart';
import 'services/print_spooler_service.dart';
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
  final double taxTotal;
  final Map<String, double> taxBreakdown;
  final double taxExclusivePortion;
  final double taxInclusivePortion;
  final double taxRoundingDelta;
  final Map<String, dynamic>? taxSummary;
  final Map<String, dynamic>? houseAccountDraft;
  final double houseAccountChargeAmount;
  final bool invoiceToHouseAccount;

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
    this.taxTotal = 0,
    this.taxBreakdown = const {},
    this.taxExclusivePortion = 0,
    this.taxInclusivePortion = 0,
    this.taxRoundingDelta = 0,
    this.taxSummary,
    this.houseAccountDraft,
    this.houseAccountChargeAmount = 0,
    this.invoiceToHouseAccount = false,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final PrintingService _printingService = PrintingService();
  final ReceiptService _receiptService = ReceiptService();
  final HouseAccountService _houseAccountService = HouseAccountService();
  bool _isConfirming = false;
  bool _includeTaxInvoice = false;
  bool _sendEmailReceipt = false;
  bool _isGeneratingReceipt = false;
  String? _generatedReceiptUrl;
  late final TextEditingController _printerIpController;
  late final TextEditingController _printerPortController;
  bool _openDrawerAfterPrint = true;
  bool _isPrintingEscPos = false;
  StreamSubscription<List<HouseAccount>>? _houseAccountSubscription;
  List<HouseAccount> _houseAccounts = [];
  HouseAccount? _selectedHouseAccount;
  bool _isPostingHouseCharge = false;
  bool _houseAccountsEnabled = false;
  String? _houseAccountStatusMessage;
  String? _currentStoreId;
  DateTime? _selectedHouseAccountDueDate;
  String? _draftHouseAccountId;

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
    _draftHouseAccountId = widget.houseAccountDraft?['accountId'] as String?;
    _selectedHouseAccountDueDate = _parseDraftDueDate(
      widget.houseAccountDraft?['dueDate'],
    );
    if (widget.invoiceToHouseAccount) {
      _houseAccountStatusMessage = 'ออเดอร์นี้ถูกวางบิลลูกหนี้แล้ว';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final storeProvider = context.read<StoreProvider>();
    final store = storeProvider.activeStore;
    final storeId = store?.id;
    if (_currentStoreId == storeId) {
      return;
    }
    _currentStoreId = storeId;
    _houseAccountSubscription?.cancel();
    final enabled = store?.houseAccountsEnabled ?? false;
    setState(() {
      _houseAccountsEnabled = enabled;
      _houseAccounts = [];
      if (!enabled) {
        _selectedHouseAccount = null;
      }
    });
    if (!enabled || store == null) {
      return;
    }
    _houseAccountSubscription = _houseAccountService
        .watchAccounts(tenantId: store.tenantId, storeId: store.id)
        .listen((accounts) {
          if (!mounted) return;
          final draftId = _draftHouseAccountId;
          HouseAccount? selected = _selectedHouseAccount;
          if (selected == null && draftId != null) {
            selected = accounts.firstWhereOrNull(
              (account) => account.id == draftId,
            );
          }
          setState(() {
            _houseAccounts = accounts;
            if (selected != null) {
              _selectedHouseAccount =
                  accounts.firstWhereOrNull(
                    (account) => account.id == selected!.id,
                  ) ??
                  selected;
            }
          });
        });
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
    final currencyProvider = context.watch<CurrencyProvider>();
    final baseStyle = TextStyle(
      fontSize: isTotal ? 18 : 16,
      fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
    );
    final colorStyle = valueColor != null
        ? baseStyle.copyWith(color: valueColor)
        : baseStyle;
    final formatted = currencyProvider.formatBaseAmount(amount);
    String? baseBreakdown;
    if (currencyProvider.displayCurrency != currencyProvider.baseCurrency) {
      baseBreakdown =
          '${amount < 0 ? '- ' : ''}${amount.abs().toStringAsFixed(2)} ${currencyProvider.baseCurrency}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: baseStyle),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatted, style: colorStyle),
              if (baseBreakdown != null)
                Text(
                  baseBreakdown,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
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

    final currencyProvider = context.watch<CurrencyProvider>();

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

    if (widget.taxTotal > 0) {
      rows.add(
        _buildSummaryRow(
          'Tax',
          widget.taxTotal,
          valueColor: Colors.teal.shade700,
        ),
      );
      widget.taxBreakdown.forEach((name, amount) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: _buildSummaryRow(
              name,
              amount,
              valueColor: Colors.teal.shade400,
            ),
          ),
        );
      });
      if (widget.taxRoundingDelta != 0) {
        rows.add(
          _buildSummaryRow(
            'Tax Rounding',
            widget.taxRoundingDelta,
            valueColor: Colors.teal.shade300,
          ),
        );
      }
      if (widget.taxInclusivePortion > 0) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'รวมภาษีในราคาแล้ว ${currencyProvider.formatBaseAmount(widget.taxInclusivePortion)}',
                style: TextStyle(color: Colors.teal.shade300, fontSize: 12),
              ),
            ),
          ),
        );
      }
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
          'Split between ${widget.splitCount} guests: ${currencyProvider.formatBaseAmount(perGuest)} each',
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
    final l10n = AppLocalizations.of(context)!;
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
                      SnackBar(
                        content: Text(l10n.checkoutCopyLinkSuccess),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_all_outlined),
                  label: Text(l10n.checkoutCopyLink),
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

    final l10n = AppLocalizations.of(context)!;
    final currencyProvider = context.watch<CurrencyProvider>();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.checkoutAppliedPaymentsTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...widget.payments.map((payment) {
              final method = payment['method']?.toString();
              final methodDisplay =
                  (method == null || method.isEmpty)
                      ? l10n.checkoutPaymentUnknownMethod
                      : method;
              final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
              final baseAmount =
                  (payment['baseAmount'] as num?)?.toDouble();
              final currencyCode =
                  (payment['currency'] as String?)?.toUpperCase();
              final amountDisplay =
                  currencyProvider.format(amount, currency: currencyCode);
              String? baseAmountDisplay;
              if (baseAmount != null &&
                  (currencyCode == null ||
                      currencyCode != currencyProvider.baseCurrency)) {
                baseAmountDisplay = currencyProvider.format(
                  baseAmount,
                  currency: currencyProvider.baseCurrency,
                );
              }
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
                            methodDisplay,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            amountDisplay,
                            style: const TextStyle(color: Colors.green),
                          ),
                          if (baseAmountDisplay != null)
                            Text(
                              baseAmountDisplay,
                              style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.black54) ??
                                  const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                            ),
                          if (reference != null && reference.isNotEmpty)
                            Text(
                              l10n.checkoutPaymentReference(reference),
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

  DateTime? _parseDraftDueDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  double get _currentHouseAccountCharge {
    if (widget.houseAccountChargeAmount > 0) {
      return widget.houseAccountChargeAmount;
    }
    if (widget.amountDueAfterCredits > 0) {
      return widget.amountDueAfterCredits;
    }
    final creditAdjusted =
        widget.totalAmount - widget.giftCardAmount - widget.storeCreditAmount;
    return creditAdjusted < 0 ? 0.0 : creditAdjusted;
  }

  Future<void> _pickHouseAccountDueDate() async {
    if (_selectedHouseAccount == null) return;
    final now = DateTime.now();
    final initial =
        _selectedHouseAccountDueDate ??
        _selectedHouseAccount!.calculateDueDate(now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() {
        _selectedHouseAccountDueDate = picked;
      });
    }
  }

  Future<void> _handleHouseAccountInvoice() async {
    if (_selectedHouseAccount == null) {
      setState(() {
        _houseAccountStatusMessage =
            'กรุณาเลือกบัญชีลูกหนี้ (House Account) ก่อนทำการวางบิล';
      });
      return;
    }
    final account = _selectedHouseAccount!;
    final amount = _currentHouseAccountCharge;
    if (amount <= 0) {
      setState(() {
        _houseAccountStatusMessage =
            'ไม่มีจำนวนเงินที่ต้องวางบิลสำหรับออเดอร์นี้';
      });
      return;
    }

    final store = context.read<StoreProvider>().activeStore;
    if (store == null) {
      setState(() {
        _houseAccountStatusMessage = 'ไม่พบข้อมูลสาขาเพื่อวางบิลลูกหนี้';
      });
      return;
    }

    setState(() {
      _isPostingHouseCharge = true;
      _houseAccountStatusMessage = null;
    });

    try {
      final dueDate =
          _selectedHouseAccountDueDate ??
          account.calculateDueDate(DateTime.now());
      final taxSummary =
          widget.taxSummary ??
          {
            'exclusiveTax': widget.taxExclusivePortion,
            'inclusiveTaxPortion': widget.taxInclusivePortion,
            'roundingDelta': widget.taxRoundingDelta,
            'total': widget.taxTotal,
            'lines': widget.taxBreakdown.entries
                .map(
                  (entry) => {
                    'id': entry.key,
                    'name': entry.key,
                    'amount': entry.value,
                  },
                )
                .toList(),
          };

      await _houseAccountService.recordCharge(
        account: account,
        orderId: widget.orderId,
        orderIdentifier: widget.orderIdentifier,
        amount: amount,
        subtotal: widget.subtotal,
        discount: widget.discountAmount,
        serviceCharge: widget.serviceChargeAmount,
        taxSummary: taxSummary,
        chargedAt: DateTime.now(),
        dueDate: dueDate,
      );

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .set({
            'paymentStatus': 'invoiced',
            'settlementType': 'houseAccount',
            'invoiceToHouseAccount': true,
            'houseAccountId': account.id,
            'houseAccountChargeAmount': amount,
            'houseAccount': {
              'accountId': account.id,
              'customerId': account.customerId,
              'customerName': account.customerName,
              'dueDate': Timestamp.fromDate(dueDate),
              'statementDay': account.statementDay,
              'paymentTermsDays': account.paymentTermsDays,
            },
            'outstandingBalance': 0.0,
            'paidTotal': widget.totalAmount - amount,
            'invoicedAt': Timestamp.now(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _isPostingHouseCharge = false;
        _houseAccountStatusMessage =
            'วางบิลเรียบร้อยสำหรับ ${account.customerName}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order ถูกวางบิลไปยังบัญชีลูกหนี้ ${account.customerName} แล้ว',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPostingHouseCharge = false;
        _houseAccountStatusMessage = 'ไม่สามารถวางบิลได้: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('วางบิล House Account ไม่สำเร็จ: $e')),
      );
    }
  }

  Widget _buildHouseAccountSection() {
    if (!_houseAccountsEnabled) {
      return const SizedBox.shrink();
    }

    final amountToInvoice = _currentHouseAccountCharge;
    final bool hasAccounts = _houseAccounts.isNotEmpty;
    final bool alreadyInvoiced = widget.invoiceToHouseAccount;
    final theme = Theme.of(context);
    final currencyProvider = context.watch<CurrencyProvider>();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'House Account / B2B Invoicing',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (amountToInvoice > 0)
                  Chip(
                    label: Text(
                      currencyProvider.formatBaseAmount(amountToInvoice),
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: theme.colorScheme.primary,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasAccounts)
              Text(
                'ยังไม่มีบัญชีลูกหนี้ที่เปิดใช้งานสำหรับสาขานี้',
                style: theme.textTheme.bodyMedium,
              )
            else
              DropdownButtonFormField<HouseAccount>(
                value:
                    _selectedHouseAccount != null &&
                        _houseAccounts.any(
                          (acc) => acc.id == _selectedHouseAccount!.id,
                        )
                    ? _houseAccounts.firstWhere(
                        (acc) => acc.id == _selectedHouseAccount!.id,
                      )
                    : null,
                decoration: const InputDecoration(
                  labelText: 'เลือกบัญชีลูกหนี้',
                  border: OutlineInputBorder(),
                ),
                items: _houseAccounts
                    .map(
                      (account) => DropdownMenuItem<HouseAccount>(
                        value: account,
                        child: Text(
                          account.creditLimit <= 0
                              ? account.customerName
                              : '${account.customerName} (คงเหลือ ${currencyProvider.formatBaseAmount(account.availableCredit)})',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedHouseAccount = value;
                    _draftHouseAccountId = value?.id;
                    if (value != null) {
                      _selectedHouseAccountDueDate = value.calculateDueDate(
                        DateTime.now(),
                      );
                    }
                  });
                },
              ),
            if (_selectedHouseAccount != null) ...[
              const SizedBox(height: 12),
              Text(
                'วงเงิน: ${_selectedHouseAccount!.creditLimit <= 0 ? 'ไม่จำกัด' : currencyProvider.formatBaseAmount(_selectedHouseAccount!.creditLimit)}'
                ' | ยอดคงค้าง: ${currencyProvider.formatBaseAmount(_selectedHouseAccount!.currentBalance)}',
              ),
              Text(
                'วันตัดรอบ: ทุกวันที่ ${_selectedHouseAccount!.statementDay} | เงื่อนไขชำระ ${_selectedHouseAccount!.paymentTermsDays} วัน',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ครบกำหนดชำระ: ${MaterialLocalizations.of(context).formatMediumDate(_selectedHouseAccountDueDate ?? _selectedHouseAccount!.calculateDueDate(DateTime.now()))}',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickHouseAccountDueDate,
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('เลือกวันครบกำหนด'),
                  ),
                ],
              ),
            ],
            if (alreadyInvoiced)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'ออเดอร์นี้ถูกวางบิลลูกหนี้แล้ว สามารถแก้ไขรายละเอียดได้จากหน้า House Account',
                  style: TextStyle(
                    color: Colors.blueGrey.shade700,
                    fontSize: 12,
                  ),
                ),
              ),
            if (_houseAccountStatusMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _houseAccountStatusMessage!,
                style: TextStyle(
                  color: _houseAccountStatusMessage!.startsWith('ไม่สามารถ')
                      ? Colors.red
                      : Colors.green,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: _isPostingHouseCharge
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt_long),
                label: Text(
                  'วางบิล ${currencyProvider.formatBaseAmount(amountToInvoice > 0 ? amountToInvoice : 0)}',
                ),
                onPressed:
                    (!hasAccounts ||
                        amountToInvoice <= 0 ||
                        _selectedHouseAccount == null ||
                        _isPostingHouseCharge ||
                        alreadyInvoiced)
                    ? null
                    : _handleHouseAccountInvoice,
              ),
            ),
          ],
        ),
      ),
    );
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
    final currencyProvider = context.read<CurrencyProvider>();
    final baseCurrency = currencyProvider.baseCurrency;
    final tenderCurrency = currencyProvider.displayCurrency;
    final convertedOutstanding = outstanding <= 0
        ? 0.0
        : currencyProvider.convert(
            amount: outstanding,
            fromCurrency: baseCurrency,
            toCurrency: tenderCurrency,
          );
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
      amount: convertedOutstanding,
      currency: tenderCurrency,
      orderId: widget.orderId,
      description: 'Order ${widget.orderIdentifier}',
      metadata: {
        'orderIdentifier': widget.orderIdentifier,
        'subtotal': widget.subtotal,
        'discount': widget.discountAmount,
        'serviceCharge': widget.serviceChargeAmount,
        'tip': widget.tipAmount,
        'splitCount': widget.splitCount,
        'baseCurrency': baseCurrency,
        'displayCurrency': tenderCurrency,
        'baseAmount': outstanding,
        'displayAmount': convertedOutstanding,
        'fxRate': outstanding == 0
            ? 1.0
            : convertedOutstanding / outstanding,
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
          'amount': convertedOutstanding,
          'currency': tenderCurrency,
          'baseAmount': outstanding,
          'baseCurrency': baseCurrency,
          'fxRate': outstanding == 0
              ? 1.0
              : convertedOutstanding / outstanding,
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
    final currencyProvider = context.watch<CurrencyProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final labelStyle =
        Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold) ??
        const TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
    final helperStyle = Theme.of(context).textTheme.bodySmall;
    final config = paymentService.activeConfig;
    final tenderCurrency = currencyProvider.displayCurrency;
    final tenderRate = currencyProvider.quotedRates[tenderCurrency] ?? 1.0;
    final lastSynced = currencyProvider.lastSynced;
    final rateFormatter = localeProvider.decimalFormatter(decimalDigits: 4);

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
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: tenderCurrency,
              decoration: const InputDecoration(
                labelText: 'Tender Currency',
                border: OutlineInputBorder(),
              ),
              items: currencyProvider.supportedCurrencies
                  .map(
                    (code) => DropdownMenuItem<String>(
                      value: code,
                      child: Text(code),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  currencyProvider.setDisplayCurrency(value);
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '1 ${currencyProvider.baseCurrency} ≈ ${rateFormatter.format(tenderRate)} $tenderCurrency',
                style: helperStyle,
              ),
            ),
            if (lastSynced != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'FX rates updated: ${DateFormat('dd MMM yyyy HH:mm').format(lastSynced.toLocal())}',
                  style: helperStyle,
                ),
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

      final spooler = context.read<PrintSpoolerService>();
      await spooler.enqueueReceipt(
        host: printerIp,
        port: printerPort ?? 9100,
        orderData: orderData,
        storeDetails: StoreReceiptDetails.fromStore(store),
        taxDetails: _buildTaxInvoiceDetails(),
        openDrawer: _openDrawerAfterPrint,
      );

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
    _houseAccountSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qrData = _generatePromptPayPayload(widget.totalAmount);
    final currencyProvider = context.watch<CurrencyProvider>();

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
                'Total Amount: ${currencyProvider.formatBaseAmount(widget.totalAmount)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildAmountBreakdown(),
              _buildExistingPaymentsCard(),
              _buildHouseAccountSection(),
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
