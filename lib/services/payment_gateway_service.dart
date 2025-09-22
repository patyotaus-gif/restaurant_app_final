import 'dart:async';

import 'package:flutter/foundation.dart';

/// Supported payment gateways for the POS checkout flow.
enum PaymentGatewayType { stripe, square, adyen }

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
    }
  }
}
