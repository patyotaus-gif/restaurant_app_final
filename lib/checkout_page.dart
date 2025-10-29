// lib/checkout_page.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:restaurant_models/restaurant_models.dart';
import 'package:url_launcher/url_launcher.dart';

import 'currency_provider.dart';
import 'locale_provider.dart';
import 'localization/app_localizations.dart';
import 'services/house_account_service.dart';
import 'services/payment_gateway_service.dart';
import 'payments/payments_service.dart';
import 'services/print_spooler_service.dart';
import 'services/printing_service.dart';
import 'services/receipt_service.dart';
import 'stock_provider.dart';
import 'store_provider.dart';
import 'widgets/omise_card_tokenizer.dart';
import 'widgets/payment_redirect_page.dart';

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

enum _WindowsChargeState { pending, success, failure }

class _WindowsChargeEvaluation {
  const _WindowsChargeEvaluation._(
    this.state, {
    this.charge,
    this.metadata,
    this.message,
  });

  factory _WindowsChargeEvaluation.pending({
    Map<String, dynamic>? charge,
    Map<String, dynamic>? metadata,
  }) {
    return _WindowsChargeEvaluation._(
      _WindowsChargeState.pending,
      charge: charge,
      metadata: metadata,
    );
  }

  factory _WindowsChargeEvaluation.success({
    required Map<String, dynamic> charge,
    Map<String, dynamic>? metadata,
  }) {
    return _WindowsChargeEvaluation._(
      _WindowsChargeState.success,
      charge: charge,
      metadata: metadata,
    );
  }

  factory _WindowsChargeEvaluation.failure({
    Map<String, dynamic>? charge,
    Map<String, dynamic>? metadata,
    String? message,
  }) {
    return _WindowsChargeEvaluation._(
      _WindowsChargeState.failure,
      charge: charge,
      metadata: metadata,
      message: message,
    );
  }

  final _WindowsChargeState state;
  final Map<String, dynamic>? charge;
  final Map<String, dynamic>? metadata;
  final String? message;
}

class _WindowsChargePollResult {
  const _WindowsChargePollResult({required this.charge, this.metadata});

  final Map<String, dynamic> charge;
  final Map<String, dynamic>? metadata;
}

class _CheckoutPageState extends State<CheckoutPage> {
  static const String _fallbackOmiseReturnUri =
      'https://restaurant-pos.web.app/payments/omise-return';
  final ReceiptService _receiptService = ReceiptService();
  final HouseAccountService _houseAccountService = HouseAccountService();
  bool _isConfirming = false;
  bool _awaitingWindowsCardConfirmation = false;
  bool _includeTaxInvoice = false;
  bool _sendEmailReceipt = false;
  bool _isGeneratingReceipt = false;
  String? _generatedReceiptUrl;
  late final DocumentReference<Map<String, dynamic>> _orderRef;
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
    _orderRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId);
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
          if (!mounted) {
            return;
          }

          void applyUpdate() {
            if (!mounted) {
              return;
            }

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
          }

          if (SchedulerBinding.instance.schedulerPhase ==
              SchedulerPhase.persistentCallbacks) {
            SchedulerBinding.instance.addPostFrameCallback(
              (_) => applyUpdate(),
            );
          } else {
            applyUpdate();
          }
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
                  style: Theme.of(context).textTheme.labelSmall,
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

    final helperStyle = Theme.of(context).textTheme.labelSmall;

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
                child: QrImage(
                  data: _generatedReceiptUrl!,
                  size: 180.0,
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
                      SnackBar(content: Text(l10n.checkoutCopyLinkSuccess)),
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
              final methodDisplay = (method == null || method.isEmpty)
                  ? l10n.checkoutPaymentUnknownMethod
                  : method;
              final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
              final baseAmount = (payment['baseAmount'] as num?)?.toDouble();
              final currencyCode = (payment['currency'] as String?)
                  ?.toUpperCase();
              final amountDisplay = currencyProvider.format(
                amount,
                currency: currencyCode,
              );
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
                              style:
                                  Theme.of(context).textTheme.labelSmall
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

      await _orderRef.set({
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
                initialValue:
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
    final storeProvider = context.read<StoreProvider>();
    try {
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();
      if (!orderDoc.exists) {
        throw Exception('Order not found!');
      }
      final store = storeProvider.activeStore;
      if (store == null) {
        throw Exception('Store information not available');
      }
      await PrintingService().previewReceipt(
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
    final storeProvider = context.read<StoreProvider>();
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

      final store = storeProvider.activeStore;
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
    if (outstanding == 0) {
      try {
        await _orderRef.update({
          'status': 'completed',
          'completedAt': Timestamp.now(),
          'paidTotal': widget.totalAmount,
          'paymentStatus': 'paid',
        });
        await _handlePostPaymentSuccess(
          _orderRef,
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
    OmiseCardTokenizationResult? cardTokenResult;

    if (gatewayService.activeGateway == PaymentGatewayType.creditDebitCard) {
      final config = gatewayService.activeConfig;
      final publicKey =
          config?.apiKey ?? config?.additionalData['publicKey'] as String?;
      if (publicKey == null || publicKey.isEmpty) {
        if (mounted) {
          setState(() {
            _isConfirming = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to process card payment: Omise public key is missing.',
              ),
            ),
          );
        }
        return;
      }

      try {
        cardTokenResult = await OmiseCardTokenizer.collectToken(
          context: context,
          publicKey: publicKey,
          amount: convertedOutstanding,
          currency: tenderCurrency,
        );
      } catch (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isConfirming = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open card entry form: $error')),
        );
        return;
      }

      if (!mounted) {
        return;
      }

      if (cardTokenResult == null) {
        setState(() {
          _isConfirming = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Card payment was cancelled.')),
        );
        return;
      }
    }

    final requestMetadata = <String, dynamic>{
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
      'fxRate': outstanding == 0 ? 1.0 : convertedOutstanding / outstanding,
    };

    final cardDetails = cardTokenResult?.card;
    if (cardDetails != null) {
      final brand = cardDetails['brand'];
      final lastDigits = cardDetails['last_digits'];
      final name = cardDetails['name'];
      final expiryMonth = cardDetails['expiration_month'];
      final expiryYear = cardDetails['expiration_year'];
      if (brand is String && brand.isNotEmpty) {
        requestMetadata['cardBrand'] = brand;
      }
      if (lastDigits is String && lastDigits.isNotEmpty) {
        requestMetadata['cardLastDigits'] = lastDigits;
      }
      if (name is String && name.isNotEmpty) {
        requestMetadata['cardHolderName'] = name;
      }
      if (expiryMonth is String && expiryMonth.isNotEmpty) {
        requestMetadata['cardExpiryMonth'] = expiryMonth;
      }
      if (expiryYear is String && expiryYear.isNotEmpty) {
        requestMetadata['cardExpiryYear'] = expiryYear;
      }
    }

    final paymentRequest = PaymentRequest(
      amount: convertedOutstanding,
      currency: tenderCurrency,
      orderId: widget.orderId,
      description: 'Order ${widget.orderIdentifier}',
      metadata: requestMetadata,
      customerEmail: _customerEmailController.text.trim().isEmpty
          ? null
          : _customerEmailController.text.trim(),
      customerName: _customerNameController.text.trim().isEmpty
          ? null
          : _customerNameController.text.trim(),
      paymentToken: cardTokenResult?.token,
    );

    final isWindowsDesktop =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

    PaymentResult paymentResult;
    if (isWindowsDesktop &&
        gatewayService.activeGateway == PaymentGatewayType.creditDebitCard &&
        cardTokenResult != null) {
      try {
        if (mounted) {
          setState(() {
            _awaitingWindowsCardConfirmation = true;
          });
        }
        paymentResult = await _processWindowsCardPayment(
          request: paymentRequest,
          cardTokenResult: cardTokenResult,
          gatewayConfig: gatewayService.activeConfig,
        );
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
      } finally {
        if (mounted) {
          setState(() {
            _awaitingWindowsCardConfirmation = false;
          });
        }
      }
    } else {
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
    }

    if (!mounted) {
      return;
    }

    await _maybeHandlePaymentRedirect(
      paymentResult: paymentResult,
      gatewayType: gatewayService.activeGateway,
    );

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
          'fxRate': outstanding == 0 ? 1.0 : convertedOutstanding / outstanding,
          'transactionId': paymentResult.transactionId,
          'processedAt': Timestamp.now(),
        },
      ]),
    };

    try {
      await _orderRef.update(payload);
      await _handlePostPaymentSuccess(
        _orderRef,
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

  Future<void> _maybeHandlePaymentRedirect({
    required PaymentResult paymentResult,
    required PaymentGatewayType gatewayType,
  }) async {
    final metadata = paymentResult.metadata;
    final redirectUrl = paymentResult.receiptUrl?.isNotEmpty == true
        ? paymentResult.receiptUrl
        : metadata['authorizeUri'] as String?;
    if (redirectUrl == null || redirectUrl.isEmpty) {
      return;
    }

    final uri = Uri.tryParse(redirectUrl);
    if (uri == null) {
      return;
    }

    final status = (metadata['status'] as String?)?.toLowerCase();
    final authorized = metadata['authorized'];
    final isWaitingFor3ds =
        gatewayType == PaymentGatewayType.creditDebitCard &&
        (authorized == false ||
            (status != null &&
                (status.contains('pending') ||
                    status.contains('authorize') ||
                    status.contains('await'))));

    final channel = (metadata['channel'] as String?)?.toLowerCase();
    final isMobileBankingFlow =
        gatewayType == PaymentGatewayType.mobileBanking ||
        channel == 'app_transfer';

    if (!isWaitingFor3ds && !isMobileBankingFlow) {
      return;
    }

    final title = isMobileBankingFlow
        ? 'เปิดแอปโมบายแบงก์กิ้ง'
        : 'ยืนยันความปลอดภัยของบัตร';
    final description = isMobileBankingFlow
        ? 'ระบบจะพาคุณไปยังแอปธนาคารเพื่ออนุมัติการชำระเงินให้เสร็จสมบูรณ์.'
        : 'โปรดยืนยัน 3-D Secure กับธนาคารของคุณเพื่อทำรายการให้สำเร็จ.';

    await PaymentRedirectLauncher.open(
      context: context,
      url: uri,
      title: title,
      description: description,
    );
  }

  Future<PaymentResult> _processWindowsCardPayment({
    required PaymentRequest request,
    required OmiseCardTokenizationResult cardTokenResult,
    PaymentGatewayConfig? gatewayConfig,
  }) async {
    final paymentsService = PaymentsService();
    PaymentsChargeResult chargeResult;
    try {
      chargeResult = await paymentsService.createCardCharge3ds(
        amountInMinorUnits: (request.amount * 100).round(),
        currency: request.currency,
        cardToken: cardTokenResult.token,
        returnUri: _resolveWindows3dsReturnUri(gatewayConfig),
        description: request.description,
        metadata: request.metadata,
        capture: true,
      );
    } on PaymentsServiceException catch (error) {
      throw PaymentGatewayException(error.message);
    } catch (error) {
      throw PaymentGatewayException(
        'ไม่สามารถสร้างคำสั่งชำระเงินกับ Omise ได้: $error',
      );
    }

    final chargeId = chargeResult.chargeId;
    if (chargeId == null || chargeId.isEmpty) {
      throw PaymentGatewayException('Omise charge is missing an identifier.');
    }

    final authorizeUri = chargeResult.authorizeUri;
    if (authorizeUri != null && authorizeUri.isNotEmpty) {
      final uri = Uri.tryParse(authorizeUri);
      if (uri != null) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          throw PaymentGatewayException(
            'ไม่สามารถเปิดเบราว์เซอร์สำหรับยืนยัน 3-D Secure ได้',
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'กรุณายืนยันการชำระเงินในหน้าต่างธนาคารที่เปิดขึ้น',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    }

    final pollResult = await _waitForWindowsPaymentCompletion(chargeId);
    final charge = pollResult.charge;

    final metadata = <String, dynamic>{
      ...request.metadata,
      'gateway': 'omise',
      'channel': 'card',
    };

    final status = charge['status'];
    if (status is String && status.isNotEmpty) {
      metadata['status'] = status;
    }
    final authorized = _coerceToBool(charge['authorized']);
    if (authorized != null) {
      metadata['authorized'] = authorized;
    }
    final paid = _coerceToBool(charge['paid']);
    if (paid != null) {
      metadata['paid'] = paid;
    }
    final captured = _coerceToBool(charge['captured']);
    if (captured != null) {
      metadata['captured'] = captured;
    }
    final failureCode = charge['failure_code'];
    if (failureCode is String && failureCode.isNotEmpty) {
      metadata['failureCode'] = failureCode;
    }
    final failureMessage = charge['failure_message'];
    if (failureMessage is String && failureMessage.isNotEmpty) {
      metadata['failureMessage'] = failureMessage;
    }
    final authorizeUriFromCharge = charge['authorize_uri'];
    if (authorizeUriFromCharge is String && authorizeUriFromCharge.isNotEmpty) {
      metadata['authorizeUri'] = authorizeUriFromCharge;
    }
    if (pollResult.metadata != null && pollResult.metadata!.isNotEmpty) {
      metadata['omiseMetadata'] = pollResult.metadata;
    }

    final card = charge['card'];
    Map<String, dynamic>? cardMap;
    if (card is Map<String, dynamic>) {
      cardMap = card;
    } else if (card is Map) {
      cardMap = Map<String, dynamic>.from(card);
    }
    if (cardMap != null) {
      final brand = cardMap['brand'];
      if (brand is String && brand.isNotEmpty) {
        metadata['cardBrand'] = brand;
      }
      final lastDigits = cardMap['last_digits'];
      if (lastDigits is String && lastDigits.isNotEmpty) {
        metadata['cardLastDigits'] = lastDigits;
      }
      final holderName = cardMap['name'];
      if (holderName is String && holderName.isNotEmpty) {
        metadata['cardHolderName'] = holderName;
      }
      final expiryMonth = cardMap['expiration_month'];
      if (expiryMonth is String && expiryMonth.isNotEmpty) {
        metadata['cardExpiryMonth'] = expiryMonth;
      }
      final expiryYear = cardMap['expiration_year'];
      if (expiryYear is String && expiryYear.isNotEmpty) {
        metadata['cardExpiryYear'] = expiryYear;
      }
    }

    final receiptUrlValue = charge['receipt_url'];
    final receiptUrl = receiptUrlValue is String && receiptUrlValue.isNotEmpty
        ? receiptUrlValue
        : null;

    return PaymentResult.success(
      transactionId: chargeId,
      receiptUrl: receiptUrl,
      metadata: metadata,
    );
  }

  Future<_WindowsChargePollResult> _waitForWindowsPaymentCompletion(
    String chargeId, {
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final docRef = FirebaseFirestore.instance
        .collection('payments')
        .doc(chargeId);

    final completer = Completer<_WindowsChargePollResult>();
    late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> sub;
    late final Timer timer;

    void resolvePending(DocumentSnapshot<Map<String, dynamic>> snapshot) {
      final data = snapshot.data();
      if (data == null) {
        return;
      }
      final evaluation = _evaluateWindowsChargeDocument(data);
      switch (evaluation.state) {
        case _WindowsChargeState.pending:
          return;
        case _WindowsChargeState.success:
          if (!completer.isCompleted) {
            completer.complete(
              _WindowsChargePollResult(
                charge: evaluation.charge ?? <String, dynamic>{},
                metadata: evaluation.metadata,
              ),
            );
          }
          break;
        case _WindowsChargeState.failure:
          if (!completer.isCompleted) {
            completer.completeError(
              PaymentGatewayException(
                evaluation.message ??
                    'การยืนยัน 3-D Secure ไม่สำเร็จ โปรดลองใหม่อีกครั้ง.',
              ),
            );
          }
          break;
      }
    }

    sub = docRef.snapshots().listen(
      resolvePending,
      onError: (error) {
        if (!completer.isCompleted) {
          completer.completeError(
            PaymentGatewayException(
              'ไม่สามารถตรวจสอบสถานะการชำระเงินได้: $error',
            ),
          );
        }
      },
    );

    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          PaymentGatewayException(
            'หมดเวลารอการยืนยัน 3-D Secure โปรดลองใหม่อีกครั้ง.',
          ),
        );
      }
    });

    try {
      return await completer.future;
    } finally {
      await sub.cancel();
      timer.cancel();
    }
  }

  _WindowsChargeEvaluation _evaluateWindowsChargeDocument(
    Map<String, dynamic> data,
  ) {
    Map<String, dynamic>? charge;
    final rawCharge = data['charge'];
    if (rawCharge is Map<String, dynamic>) {
      charge = rawCharge;
    } else if (rawCharge is Map) {
      charge = Map<String, dynamic>.from(rawCharge);
    }

    final normalizedCharge = charge != null
        ? Map<String, dynamic>.from(charge)
        : Map<String, dynamic>.from(data);
    Map<String, dynamic>? metadata;
    final rawMetadata = data['metadata'];
    if (rawMetadata is Map<String, dynamic>) {
      metadata = rawMetadata;
    } else if (rawMetadata is Map) {
      metadata = Map<String, dynamic>.from(rawMetadata);
    }

    final statusValue = normalizedCharge['status'] ?? data['status'];
    final status = statusValue is String ? statusValue.toLowerCase() : null;
    final authorized = _coerceToBool(normalizedCharge['authorized']);
    final paid = _coerceToBool(normalizedCharge['paid']);
    final captured = _coerceToBool(normalizedCharge['captured']);
    final refunded = _coerceToBool(
      normalizedCharge['refunded'] ?? normalizedCharge['refunded_amount'],
    );
    final reversed = _coerceToBool(normalizedCharge['reversed']);
    final voided =
        _coerceToBool(normalizedCharge['voided'] ?? normalizedCharge['void']) ==
        true;
    final failureCode = normalizedCharge['failure_code'] ?? data['failureCode'];
    final failureMessage =
        normalizedCharge['failure_message'] ?? data['failureMessage'];

    const successStatuses = <String>{
      'successful',
      'succeeded',
      'paid',
      'captured',
      'completed',
      'authorized',
      'closed',
    };
    const failureStatuses = <String>{
      'failed',
      'expired',
      'void',
      'voided',
      'cancelled',
      'canceled',
      'rejected',
      'reversed',
      'refunded',
    };

    final hasFailure =
        refunded == true ||
        reversed == true ||
        voided ||
        failureCode != null ||
        (status != null && failureStatuses.contains(status)) ||
        (authorized == false &&
            status != null &&
            failureStatuses.contains(status));

    if (hasFailure) {
      final message = (failureMessage is String && failureMessage.isNotEmpty)
          ? failureMessage
          : 'การยืนยัน 3-D Secure ไม่สำเร็จ'
                ' (${(status ?? 'failed').toUpperCase()})';
      return _WindowsChargeEvaluation.failure(
        charge: normalizedCharge,
        metadata: metadata,
        message: message,
      );
    }

    final hasSuccess =
        paid == true ||
        captured == true ||
        (authorized == true && failureCode == null) ||
        (status != null && successStatuses.contains(status));

    if (hasSuccess) {
      return _WindowsChargeEvaluation.success(
        charge: normalizedCharge,
        metadata: metadata,
      );
    }

    return _WindowsChargeEvaluation.pending(
      charge: normalizedCharge,
      metadata: metadata,
    );
  }

  String _resolveWindows3dsReturnUri(PaymentGatewayConfig? config) {
    final additional = config?.additionalData;
    final configured = additional is Map<String, dynamic>
        ? additional['returnUri'] as String?
        : null;
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return _fallbackOmiseReturnUri;
  }

  bool? _coerceToBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == 'yes' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == 'no' || normalized == '0') {
        return false;
      }
    }
    return null;
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
    final theme = Theme.of(context);
    final labelStyle =
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold) ??
        const TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
    final helperStyle = theme.textTheme.labelSmall;
    final config = paymentService.activeConfig;
    final additional = config?.additionalData ?? const <String, dynamic>{};
    final publicKey = config?.apiKey ?? additional['publicKey'] as String?;
    final secretKey = config?.secretKey ?? additional['secretKey'] as String?;
    final defaultSource = additional['defaultSourceType'] as String?;
    final tenderCurrency = currencyProvider.displayCurrency;
    final tenderRate = currencyProvider.quotedRates[tenderCurrency] ?? 1.0;
    final lastSynced = currencyProvider.lastSynced;
    final rateFormatter = context.read<LocaleProvider>().decimalFormatter(
      decimalDigits: 4,
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Omise Node Payments', style: labelStyle),
            if (helperStyle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Text(
                  'All in-person payments are now routed through the official omise-node SDK for stronger reliability and security.',
                  style: helperStyle,
                ),
              ),
            Text(
              'Active adapter: ${PaymentGatewayService.describeGateway(paymentService.activeGateway)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tender currency: $tenderCurrency',
              style: theme.textTheme.bodyMedium,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
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
            const SizedBox(height: 12),
            Text('Public key: ${_maskCredential(publicKey)}'),
            Text('Secret key: ${_maskCredential(secretKey)}'),
            if (defaultSource != null && defaultSource.isNotEmpty)
              Text('Default source: $defaultSource'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  launchUrl(Uri.parse('https://github.com/omise/omise-node'));
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('View omise-node documentation'),
              ),
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
    final helperStyle = Theme.of(context).textTheme.labelSmall;

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
    final storeProvider = context.read<StoreProvider>();
    final spooler = context.read<PrintSpoolerService>();

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

      final store = storeProvider.activeStore;
      if (store == null) {
        throw Exception('Store information not available');
      }

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

  Future<void> _handlePrintReceipt() {
    return _printViaEscPos();
  }

  Future<void> _handlePostPaymentSuccess(
    DocumentReference<Map<String, dynamic>> orderRef, {
    required String successMessage,
  }) async {
    StockProvider? stockProvider;
    try {
      stockProvider = Provider.of<StockProvider>(context, listen: false);
    } catch (_) {
      stockProvider = null;
    }

    final orderSnapshot = await orderRef.get();
    final data = orderSnapshot.data();

    if (data != null) {
      final usage = (data['ingredientUsage'] as List<dynamic>?) ?? [];
      final stockDeducted = data['stockDeducted'] == true;

      if (usage.isNotEmpty && !stockDeducted && stockProvider != null) {
        try {
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
    context.go('/floorplan');
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
    final currencyProvider = context.watch<CurrencyProvider>();
    final store = context.watch<StoreProvider>().activeStore;
    final merchantName = store?.name;
    final merchantCity = store?.address;

    return Scaffold(
      appBar: AppBar(
        title: Text('Checkout • ${widget.orderIdentifier}'),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _orderRef.snapshots(),
        builder: (context, snapshot) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Secure Checkout',
                  style:
                      Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ) ??
                      const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (merchantName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      merchantCity != null
                          ? '$merchantName • $merchantCity'
                          : merchantName,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'ไม่สามารถโหลดสถานะการชำระเงินได้: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                const SizedBox(height: 16),
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
                  alignment: WrapAlignment.start,
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
                      label: Text(
                        _isPrintingEscPos ? 'Printing...' : 'Print Receipt',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      onPressed: _isPrintingEscPos ? null : _handlePrintReceipt,
                    ),
                    ElevatedButton.icon(
                      icon: _isConfirming
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(
                        _isConfirming ? 'Processing...' : 'Confirm Payment',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      onPressed: _isConfirming ? null : _confirmPayment,
                    ),
                  ],
                ),
                if (_awaitingWindowsCardConfirmation)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'กำลังรอยืนยัน 3-D Secure จากธนาคาร...',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
