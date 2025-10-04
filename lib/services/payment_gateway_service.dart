import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
/// Supported payment gateways for the POS checkout flow.
enum PaymentGatewayType {
  stripe,
  square,
  adyen,
  omise,
  creditDebitCard,
  promptPay,
  mobileBanking,
  trueMoneyWallet,
  rabbitLinePay,
  weChatPay,
  billPayment,
}

/// Data transfer object describing a payment request that should be sent to
/// the configured payment gateway adapter.
class PaymentRequest {
  const PaymentRequest({
    required this.amount,
    required this.currency,
    required this.orderId,
    this.description,
    this.metadata = const <String, dynamic>{},
    this.customerEmail,
    this.customerName,
  });

  final double amount;
  final String currency;
  final String orderId;
  final String? description;
  final Map<String, dynamic> metadata;
  final String? customerEmail;
  final String? customerName;
}

/// Result returned from a payment gateway adapter.
class PaymentResult {
  const PaymentResult({
    required this.success,
    required this.transactionId,
    this.receiptUrl,
    this.message,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? const <String, dynamic>{};

  factory PaymentResult.success({
    required String transactionId,
    String? receiptUrl,
    Map<String, dynamic>? metadata,
  }) {
    return PaymentResult(
      success: true,
      transactionId: transactionId,
      receiptUrl: receiptUrl,
      metadata: metadata,
    );
  }

  factory PaymentResult.failure(String message) {
    return PaymentResult(success: false, transactionId: '', message: message);
  }

  final bool success;
  final String transactionId;
  final String? receiptUrl;
  final String? message;
  final Map<String, dynamic> metadata;
}

/// Configuration shared with adapters. The fields are intentionally generic so
/// that individual gateways can leverage what they need without forcing
/// specific keys on the entire application.
class PaymentGatewayConfig {
  const PaymentGatewayConfig({
    this.apiKey,
    this.secretKey,
    this.merchantAccount,
    this.additionalData = const <String, dynamic>{},
  });

  final String? apiKey;
  final String? secretKey;
  final String? merchantAccount;
  final Map<String, dynamic> additionalData;
}

/// Exception that represents a failure while communicating with the gateway.
class PaymentGatewayException implements Exception {
  PaymentGatewayException(this.message);

  final String message;

  @override
  String toString() => 'PaymentGatewayException: $message';
}

/// Base adapter contract for a payment gateway implementation.
abstract class PaymentGatewayAdapter {
  PaymentGatewayAdapter(this.config);

  final PaymentGatewayConfig? config;

  PaymentGatewayType get type;

  Future<PaymentResult> processPayment(PaymentRequest request);

  Future<void> refundPayment(String transactionId, {double? amount});
}

class StripePaymentAdapter extends PaymentGatewayAdapter {
  StripePaymentAdapter(PaymentGatewayConfig? config) : super(config);

  @override
  PaymentGatewayType get type => PaymentGatewayType.stripe;

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    await Future.delayed(const Duration(milliseconds: 450));
    if (request.amount <= 0) {
      return PaymentResult.failure('Amount must be greater than zero.');
    }

    final transactionId =
        'stripe_${DateTime.now().millisecondsSinceEpoch.toString()}';
    final metadata = <String, dynamic>{
      ...request.metadata,
      'gateway': 'stripe',
      if (config?.merchantAccount != null)
        'merchantAccount': config!.merchantAccount,
    };
    return PaymentResult.success(
      transactionId: transactionId,
      receiptUrl: 'https://dashboard.stripe.com/payments/$transactionId',
      metadata: metadata,
    );
  }

  @override
  Future<void> refundPayment(String transactionId, {double? amount}) async {
    await Future.delayed(const Duration(milliseconds: 250));
  }
}

class SquarePaymentAdapter extends PaymentGatewayAdapter {
  SquarePaymentAdapter(PaymentGatewayConfig? config) : super(config);

  @override
  PaymentGatewayType get type => PaymentGatewayType.square;

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (request.amount <= 0) {
      return PaymentResult.failure('Amount must be greater than zero.');
    }

    final transactionId =
        'square_${DateTime.now().millisecondsSinceEpoch.toString()}';
    final metadata = <String, dynamic>{
      ...request.metadata,
      'gateway': 'square',
      if (config?.additionalData['locationId'] != null)
        'locationId': config!.additionalData['locationId'],
    };
    return PaymentResult.success(
      transactionId: transactionId,
      receiptUrl: 'https://squareup.com/payments/$transactionId',
      metadata: metadata,
    );
  }

  @override
  Future<void> refundPayment(String transactionId, {double? amount}) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }
}

class AdyenPaymentAdapter extends PaymentGatewayAdapter {
  AdyenPaymentAdapter(PaymentGatewayConfig? config) : super(config);

  @override
  PaymentGatewayType get type => PaymentGatewayType.adyen;

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    await Future.delayed(const Duration(milliseconds: 520));
    if (request.amount <= 0) {
      return PaymentResult.failure('Amount must be greater than zero.');
    }

    final transactionId =
        'adyen_${DateTime.now().millisecondsSinceEpoch.toString()}';
    final metadata = <String, dynamic>{
      ...request.metadata,
      'gateway': 'adyen',
      if (config?.merchantAccount != null)
        'merchantAccount': config!.merchantAccount,
    };
    return PaymentResult.success(
      transactionId: transactionId,
      receiptUrl:
          'https://ca-live.adyen.com/ca/ca/accounts/showTx.shtml?pspReference=$transactionId',
      metadata: metadata,
    );
  }

  @override
  Future<void> refundPayment(String transactionId, {double? amount}) async {
    await Future.delayed(const Duration(milliseconds: 320));
  }
}

class CreditDebitCardPaymentAdapter extends PaymentGatewayAdapter {
  CreditDebitCardPaymentAdapter(PaymentGatewayConfig? config) : super(config);

  @override
  PaymentGatewayType get type => PaymentGatewayType.creditDebitCard;

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    await Future.delayed(const Duration(milliseconds: 420));
    if (request.amount <= 0) {
      return PaymentResult.failure('Amount must be greater than zero.');
    }

    final transactionId =
        'card_${DateTime.now().millisecondsSinceEpoch.toString()}';
    final metadata = <String, dynamic>{
      ...request.metadata,
      'gateway': 'in_house_card',
      'channel': 'credit_debit',
      if (config?.merchantAccount != null)
        'merchantAccount': config!.merchantAccount,
    };
    return PaymentResult.success(
      transactionId: transactionId,
      receiptUrl: 'https://merchant-portal.example/cards/$transactionId',
      metadata: metadata,
    );
  }

  @override
  Future<void> refundPayment(String transactionId, {double? amount}) async {
    await Future.delayed(const Duration(milliseconds: 280));
  }
}

class PromptPayPaymentAdapter extends PaymentGatewayAdapter {
  PromptPayPaymentAdapter(PaymentGatewayConfig? config) : super(config);

  @override
  PaymentGatewayType get type => PaymentGatewayType.promptPay;

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    await Future.delayed(const Duration(milliseconds: 380));
    if (request.amount <= 0) {
      return PaymentResult.failure('Amount must be greater than zero.');
    }

    final transactionId =
        'promptpay_${DateTime.now().millisecondsSinceEpoch.toString()}';
    final metadata = <String, dynamic>{
      ...request.metadata,
      'gateway': 'promptpay',
      'channel': 'qr_payment',
      if (config?.additionalData['billerId'] != null)
        'billerId': config!.additionalData['billerId'],
    };
    return PaymentResult.success(
      transactionId: transactionId,
      receiptUrl:
          'https://smart-portal.example/promptpay/transactions/$transactionId',
      metadata: metadata,
    );
  }

  @override
  Future<void> refundPayment(String transactionId, {double? amount}) async {
    await Future.delayed(const Duration(milliseconds: 260));
  }
}

class MobileBankingPaymentAdapter extends PaymentGatewayAdapter {
  MobileBankingPaymentAdapter(PaymentGatewayConfig? config) : super(config);

  @override
  PaymentGatewayType get type => PaymentGatewayType.mobileBanking;

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    await Future.delayed(const Duration(milliseconds: 460));
    if (request.amount <= 0) {
      return PaymentResult.failure('Amount must be greater than zero.');
    }

    final transactionId =
        'mobilebank_${DateTime.now().millisecondsSinceEpoch.toString()}';
    final metadata = <String, dynamic>{
      ...request.metadata,
      'gateway': 'mobile_banking',
      'channel': 'app_transfer',
      if (config?.additionalData['bankCode'] != null)
        'bankCode': config!.additionalData['bankCode'],
    };
    return PaymentResult.success(
      transactionId: transactionId,
      receiptUrl:
          'https://merchant-portal.example/mobilebanking/$transactionId',
      metadata: metadata,
    );
  }

  @override
  Future<void> refundPayment(String transactionId, {double? amount}) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }
}

class TrueMoneyWalletPaymentAdapter extends PaymentGatewayAdapter {
  TrueMoneyWalletPaymentAdapter(PaymentGatewayConfig? config) : super(config);

  @override
  PaymentGatewayType get type => PaymentGatewayType.trueMoneyWallet;

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    await Future.delayed(const Duration(milliseconds: 410));
    if (request.amount <= 0) {
      return PaymentResult.failure('Amount must be greater than zero.');
    }

    final transactionId =
        'truemoney_${DateTime.now().millisecondsSinceEpoch.toString()}';
    final metadata = <String, dynamic>{
      ...request.metadata,
      'gateway': 'truemoney',
      'channel': 'ewallet',
      if (config?.additionalData['merchantWalletId'] != null)
        'merchantWalletId': config!.additionalData['merchantWalletId'],
    };
    return PaymentResult.success(
      transactionId: transactionId,
      receiptUrl:
          'https://merchant-portal.example/truemoney/$transactionId',
      metadata: metadata,
    );
  }

  @override
  Future<void> refundPayment(String transactionId, {double? amount}) async {
    await Future.delayed(const Duration(milliseconds: 270));
  }
}

class RabbitLinePayPaymentAdapter extends PaymentGatewayAdapter {
  RabbitLinePayPaymentAdapter(PaymentGatewayConfig? config) : super(config);

  @override
  PaymentGatewayType get type => PaymentGatewayType.rabbitLinePay;

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    await Future.delayed(const Duration(milliseconds: 480));
    if (request.amount <= 0) {
      return PaymentResult.failure('Amount must be greater than zero.');
    }

    final transactionId =
        'rabbitline_${DateTime.now().millisecondsSinceEpoch.toString()}';
    final metadata = <String, dynamic>{
      ...request.metadata,
      'gateway': 'rabbit_line_pay',
      'channel': 'ewallet',
      if (config?.additionalData['channelId'] != null)
        'channelId': config!.additionalData['channelId'],
    };
    return PaymentResult.success(
      transactionId: transactionId,
      receiptUrl:
          'https://merchant-portal.example/rabbitlinepay/$transactionId',
      metadata: metadata,
    );
  }

  @override
  Future<void> refundPayment(String transactionId, {double? amount}) async {
    await Future.delayed(const Duration(milliseconds: 310));
  }
}

class WeChatPayPaymentAdapter extends PaymentGatewayAdapter {
  WeChatPayPaymentAdapter(PaymentGatewayConfig? config) : super(config);

  @override
  PaymentGatewayType get type => PaymentGatewayType.weChatPay;

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (request.amount <= 0) {
      return PaymentResult.failure('Amount must be greater than zero.');
    }

    final transactionId =
        'wechatpay_${DateTime.now().millisecondsSinceEpoch.toString()}';
    final metadata = <String, dynamic>{
      ...request.metadata,
      'gateway': 'wechat_pay',
      'channel': 'cross_border_qr',
      if (config?.additionalData['mchId'] != null)
        'mchId': config!.additionalData['mchId'],
    };
    return PaymentResult.success(
      transactionId: transactionId,
      receiptUrl:
          'https://merchant-portal.example/wechatpay/$transactionId',
      metadata: metadata,
    );
  }

  @override
  Future<void> refundPayment(String transactionId, {double? amount}) async {
    await Future.delayed(const Duration(milliseconds: 320));
  }
}

class BillPaymentAdapter extends PaymentGatewayAdapter {
  BillPaymentAdapter(PaymentGatewayConfig? config) : super(config);

  @override
  PaymentGatewayType get type => PaymentGatewayType.billPayment;

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    await Future.delayed(const Duration(milliseconds: 450));
    if (request.amount <= 0) {
      return PaymentResult.failure('Amount must be greater than zero.');
    }

    final transactionId =
        'billpay_${DateTime.now().millisecondsSinceEpoch.toString()}';
    final metadata = <String, dynamic>{
      ...request.metadata,
      'gateway': 'bill_payment',
      'channel': 'offline_counter',
      if (config?.additionalData['referenceCode'] != null)
        'referenceCode': config!.additionalData['referenceCode'],
    };
    return PaymentResult.success(
      transactionId: transactionId,
      receiptUrl:
          'https://merchant-portal.example/billpayment/$transactionId',
      metadata: metadata,
    );
  }

  @override
  Future<void> refundPayment(String transactionId, {double? amount}) async {
    await Future.delayed(const Duration(milliseconds: 330));
  }
}

/// Service responsible for orchestrating payment gateway adapters and exposing
/// them to the Flutter widget tree via Provider.
class PaymentGatewayService with ChangeNotifier {
  PaymentGatewayService({
    PaymentGatewayType initialGateway = PaymentGatewayType.stripe,
    Map<PaymentGatewayType, PaymentGatewayConfig>? configs,
  }) : _configs = Map<PaymentGatewayType, PaymentGatewayConfig>.from(
         configs ?? const <PaymentGatewayType, PaymentGatewayConfig>{},
       ) {
    _adapter = _createAdapterFor(initialGateway);
  }

  final Map<PaymentGatewayType, PaymentGatewayConfig> _configs;
  late PaymentGatewayAdapter _adapter;

  PaymentGatewayType get activeGateway => _adapter.type;
  PaymentGatewayConfig? get activeConfig => _configs[activeGateway];

  List<PaymentGatewayType> get supportedGateways =>
      PaymentGatewayType.values.toList(growable: false);

  Future<PaymentResult> processPayment(PaymentRequest request) async {
    final result = await _adapter.processPayment(request);
    if (!result.success) {
      throw PaymentGatewayException(
        result.message ??
            'Payment failed when using ${describeEnum(_adapter.type)}.',
      );
    }
    return result;
  }

  Future<void> refundPayment(String transactionId, {double? amount}) {
    return _adapter.refundPayment(transactionId, amount: amount);
  }

  void switchGateway(PaymentGatewayType type) {
    if (_adapter.type == type) {
      return;
    }
    _adapter = _createAdapterFor(type);
    notifyListeners();
  }

  void updateConfig(PaymentGatewayType type, PaymentGatewayConfig config) {
    _configs[type] = config;
    if (_adapter.type == type) {
      _adapter = _createAdapterFor(type);
      notifyListeners();
    }
  }

  static String describeGateway(PaymentGatewayType type) {
    switch (type) {
      case PaymentGatewayType.stripe:
        return 'Stripe';
      case PaymentGatewayType.square:
        return 'Square';
      case PaymentGatewayType.adyen:
        return 'Adyen';
      case PaymentGatewayType.omise:
        return 'Omise';
      case PaymentGatewayType.creditDebitCard:
        return 'บัตรเครดิต/เดบิต';
      case PaymentGatewayType.promptPay:
        return 'QR พร้อมเพย์';
      case PaymentGatewayType.mobileBanking:
        return 'โมบายล์แบงก์กิ้ง';
      case PaymentGatewayType.trueMoneyWallet:
        return 'ทรูมันนี่ วอลเล็ท';
      case PaymentGatewayType.rabbitLinePay:
        return 'Rabbit LINE Pay';
      case PaymentGatewayType.weChatPay:
        return 'WeChat Pay';
      case PaymentGatewayType.billPayment:
        return 'บิลเพย์เมนต์';
    }
  }

  PaymentGatewayAdapter _createAdapterFor(PaymentGatewayType type) {
    final config = _configs[type];
    switch (type) {
      case PaymentGatewayType.stripe:
        return StripePaymentAdapter(config);
      case PaymentGatewayType.square:
        return SquarePaymentAdapter(config);
      case PaymentGatewayType.adyen:
        return AdyenPaymentAdapter(config);
      case PaymentGatewayType.omise:
        return OmisePaymentAdapter(config);
      case PaymentGatewayType.creditDebitCard:
        return CreditDebitCardPaymentAdapter(config);
      case PaymentGatewayType.promptPay:
        return PromptPayPaymentAdapter(config);
      case PaymentGatewayType.mobileBanking:
        return MobileBankingPaymentAdapter(config);
      case PaymentGatewayType.trueMoneyWallet:
        return TrueMoneyWalletPaymentAdapter(config);
      case PaymentGatewayType.rabbitLinePay:
        return RabbitLinePayPaymentAdapter(config);
      case PaymentGatewayType.weChatPay:
        return WeChatPayPaymentAdapter(config);
      case PaymentGatewayType.billPayment:
        return BillPaymentAdapter(config);
    }
  }
}

class OmisePaymentAdapter extends PaymentGatewayAdapter {
  OmisePaymentAdapter(PaymentGatewayConfig? config) : super(config);

  @override
  PaymentGatewayType get type => PaymentGatewayType.omise;

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    if (request.amount <= 0) {
      throw PaymentGatewayException('Amount must be greater than zero.');
    }

    final config = this.config;
    if (config == null) {
      throw PaymentGatewayException('Omise gateway is not configured.');
    }

    final publicKey =
        config.apiKey ?? config.additionalData['publicKey'] as String?;
    final secretKey =
        config.secretKey ?? config.additionalData['secretKey'] as String?;
    if (publicKey == null || publicKey.isEmpty) {
      throw PaymentGatewayException('Omise public key is missing.');
    }
    if (secretKey == null || secretKey.isEmpty) {
      throw PaymentGatewayException('Omise secret key is missing.');
    }

    final currency = request.currency.trim();
    if (currency.isEmpty) {
      throw PaymentGatewayException('Currency is required for Omise payments.');
    }

    final sourceType = (request.metadata['sourceType'] ??
        config.additionalData['defaultSourceType']) as String?;
    if (sourceType == null || sourceType.isEmpty) {
      throw PaymentGatewayException(
        'Omise source type is not configured. Provide it in request metadata or configuration.',
      );
    }

    final amountInSubunits = (request.amount * 100).round();
    final sharedMetadata = <String, dynamic>{
      'orderId': request.orderId,
      ...request.metadata,
    };

    try {
      final sourceResponse = await http.post(
        Uri.https('vault.omise.co', '/sources'),
        headers: _authorizationHeaders(publicKey),
        body: jsonEncode({
          'type': sourceType,
          'amount': amountInSubunits,
          'currency': currency.toLowerCase(),
          'metadata': sharedMetadata,
          if (request.customerEmail != null) 'email': request.customerEmail,
          if (request.customerName != null) 'name': request.customerName,
        }),
      );

      final sourceData =
          _decodeResponse(sourceResponse, action: 'create source');
      final sourceId = sourceData['id'] as String?;
      if (sourceId == null || sourceId.isEmpty) {
        throw PaymentGatewayException(
          'Omise did not return a source identifier.',
        );
      }

      final chargeResponse = await http.post(
        Uri.https('api.omise.co', '/charges'),
        headers: _authorizationHeaders(secretKey),
        body: jsonEncode({
          'amount': amountInSubunits,
          'currency': currency.toLowerCase(),
          'source': sourceId,
          'description':
              request.description ?? 'Order ${request.orderId} via Omise',
          'metadata': sharedMetadata,
        }),
      );

      final chargeData =
          _decodeResponse(chargeResponse, action: 'create charge');
      final transactionId = chargeData['id'] as String?;
      if (transactionId == null || transactionId.isEmpty) {
        throw PaymentGatewayException(
          'Omise charge is missing a transaction identifier.',
        );
      }

      final metadata = <String, dynamic>{
        ...sharedMetadata,
        'gateway': 'omise',
        'sourceId': sourceId,
        'sourceType': sourceData['type'],
        if (chargeData['status'] != null) 'status': chargeData['status'],
        if (chargeData['authorized'] != null)
          'authorized': chargeData['authorized'],
        if (chargeData['metadata'] is Map<String, dynamic>)
          'omiseMetadata': Map<String, dynamic>.from(
            chargeData['metadata'] as Map<String, dynamic>,
          ),
      };

      return PaymentResult.success(
        transactionId: transactionId,
        receiptUrl: (chargeData['receipt_url'] as String?) ??
            (chargeData['authorize_uri'] as String?),
        metadata: metadata,
      );
    } on PaymentGatewayException {
      rethrow;
    } catch (error) {
      throw PaymentGatewayException(
        'Unexpected Omise payment error: $error',
      );
    }
  }

  @override
  Future<void> refundPayment(String transactionId, {double? amount}) async {
    if (transactionId.isEmpty) {
      throw PaymentGatewayException('Transaction ID is required for refunds.');
    }

    final config = this.config;
    if (config == null) {
      throw PaymentGatewayException('Omise gateway is not configured.');
    }

    final secretKey =
        config.secretKey ?? config.additionalData['secretKey'] as String?;
    if (secretKey == null || secretKey.isEmpty) {
      throw PaymentGatewayException('Omise secret key is missing.');
    }

    final body = <String, dynamic>{};
    if (amount != null) {
      if (amount <= 0) {
        throw PaymentGatewayException('Refund amount must be positive.');
      }
      body['amount'] = (amount * 100).round();
    }

    final response = await http.post(
      Uri.https('api.omise.co', '/charges/$transactionId/refunds'),
      headers: _authorizationHeaders(secretKey),
      body: jsonEncode(body),
    );

    _decodeResponse(response, action: 'issue refund');
  }

  static Map<String, String> _authorizationHeaders(String key) {
    final token = base64Encode(utf8.encode('$key:'));
    return <String, String>{
      'Authorization': 'Basic $token',
      'Content-Type': 'application/json; charset=utf-8',
    };
  }

  static Map<String, dynamic> _decodeResponse(
    http.Response response, {
    required String action,
  }) {
    var data = <String, dynamic>{};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    }

    if (response.statusCode >= 400) {
      final message = _resolveErrorMessage(data) ??
          'Failed to $action with Omise (status ${response.statusCode}).';
      throw PaymentGatewayException(message);
    }

    return data;
  }

  static String? _resolveErrorMessage(Map<String, dynamic> body) {
    if (body['message'] is String && (body['message'] as String).isNotEmpty) {
      return body['message'] as String;
    }
    final error = body['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
      final code = error['code'];
      if (code is String && code.isNotEmpty) {
        return code;
      }
    }
    return null;
  }
}
