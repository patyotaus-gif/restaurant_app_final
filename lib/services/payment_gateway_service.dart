import 'dart:async';

import 'package:flutter/foundation.dart';

import '../payments/payments_service.dart';
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
    this.paymentToken,
  });

  final double amount;
  final String currency;
  final String orderId;
  final String? description;
  final Map<String, dynamic> metadata;
  final String? customerEmail;
  final String? customerName;
  final String? paymentToken;
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
  CreditDebitCardPaymentAdapter(
    PaymentGatewayConfig? config,
    this._paymentsService,
  ) : super(config);

  static const String _fallbackReturnUri =
      'https://restaurant-pos.web.app/payments/omise-return';

  final PaymentsService _paymentsService;

  @override
  PaymentGatewayType get type => PaymentGatewayType.creditDebitCard;

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    if (request.amount <= 0) {
      throw PaymentGatewayException('Amount must be greater than zero.');
    }

    final token = request.paymentToken;
    if (token == null || token.isEmpty) {
      throw PaymentGatewayException(
        'Card token is missing. Please tokenize the card before charging.',
      );
    }

    final currency = request.currency.trim();
    if (currency.isEmpty) {
      throw PaymentGatewayException(
        'Currency is required for Omise card payments.',
      );
    }

    final amountInSubunits = (request.amount * 100).round();
    final sharedMetadata = <String, dynamic>{
      'orderId': request.orderId,
      ...request.metadata,
    };
    sharedMetadata.remove('sourceMetadata');
    sharedMetadata.remove('sourceData');

    try {
      final config = this.config;
      final returnUri = _resolveReturnUri(config);
      final chargeResult = await _paymentsService.createCardCharge3ds(
        amountInMinorUnits: amountInSubunits,
        currency: currency,
        cardToken: token,
        returnUri: returnUri,
        description: request.description,
        metadata: sharedMetadata,
        capture: true,
      );

      final chargeData = chargeResult.charge;
      final transactionId = chargeResult.chargeId ?? chargeData['id'] as String?;
      if (transactionId == null || transactionId.isEmpty) {
        throw PaymentGatewayException(
          'Omise card charge is missing a transaction identifier.',
        );
      }

      final metadata = <String, dynamic>{
        ...sharedMetadata,
        'gateway': 'omise',
        'channel': 'card',
      };

      final status = _stringOrNull(chargeData['status']);
      if (status != null) {
        metadata['status'] = status;
      }
      final authorized = _coerceToBool(chargeData['authorized']);
      if (authorized != null) {
        metadata['authorized'] = authorized;
      }
      final paid = _coerceToBool(chargeData['paid']);
      if (paid != null) {
        metadata['paid'] = paid;
      }
      final captured = _coerceToBool(chargeData['captured']);
      if (captured != null) {
        metadata['captured'] = captured;
      }
      final failureCode = _stringOrNull(chargeData['failure_code']);
      if (failureCode != null) {
        metadata['failureCode'] = failureCode;
      }
      final failureMessage = _stringOrNull(chargeData['failure_message']);
      if (failureMessage != null) {
        metadata['failureMessage'] = failureMessage;
      }

      final authorizeUri =
          chargeResult.authorizeUri ?? _stringOrNull(chargeData['authorize_uri']);
      if (authorizeUri != null) {
        metadata['authorizeUri'] = authorizeUri;
      }

      final cardData = chargeData['card'];
      if (cardData is Map<String, dynamic>) {
        final brand = cardData['brand'];
        final lastDigits = cardData['last_digits'];
        final name = cardData['name'];
        final expiryMonth = cardData['expiration_month'];
        final expiryYear = cardData['expiration_year'];
        if (brand is String && brand.isNotEmpty) {
          metadata['cardBrand'] = brand;
        }
        if (lastDigits is String && lastDigits.isNotEmpty) {
          metadata['cardLastDigits'] = lastDigits;
        }
        if (name is String && name.isNotEmpty) {
          metadata['cardHolderName'] = name;
        }
        if (expiryMonth is String && expiryMonth.isNotEmpty) {
          metadata['cardExpiryMonth'] = expiryMonth;
        }
        if (expiryYear is String && expiryYear.isNotEmpty) {
          metadata['cardExpiryYear'] = expiryYear;
        }
      }

      final receiptUrl =
          _stringOrNull(chargeData['receipt_url']) ?? authorizeUri;

      return PaymentResult.success(
        transactionId: transactionId,
        receiptUrl: receiptUrl,
        metadata: metadata,
      );
    } on PaymentGatewayException {
      rethrow;
    } on PaymentsServiceException catch (error) {
      throw PaymentGatewayException(error.message);
    } catch (error) {
      throw PaymentGatewayException(
        'Unexpected Omise card payment error: $error',
      );
    }
  }

  @override
  Future<void> refundPayment(String transactionId, {double? amount}) async {
    throw PaymentGatewayException(
      'Refunds must be processed from the Omise dashboard when using Cloud Functions.',
    );
  }

  String _resolveReturnUri(PaymentGatewayConfig? config) {
    final additional = config?.additionalData;
    final configured = additional is Map<String, dynamic>
        ? additional['returnUri'] as String?
        : null;
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return _fallbackReturnUri;
  }
}

class PromptPayPaymentAdapter extends PaymentGatewayAdapter {
  PromptPayPaymentAdapter(
    PaymentGatewayConfig? config,
    this._paymentsService,
  ) : super(config);

  final PaymentsService _paymentsService;

  @override
  PaymentGatewayType get type => PaymentGatewayType.promptPay;

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    if (request.amount <= 0) {
      throw PaymentGatewayException('Amount must be greater than zero.');
    }

    final currency = request.currency.trim();
    if (currency.isEmpty) {
      throw PaymentGatewayException('Currency is required for PromptPay.');
    }

    final amountInMinorUnits = (request.amount * 100).round();
    final sharedMetadata = <String, dynamic>{
      'orderId': request.orderId,
      ...request.metadata,
    };
    sharedMetadata.remove('sourceMetadata');
    sharedMetadata.remove('sourceData');

    try {
      final result = await _paymentsService.createPromptPayCharge(
        amountInMinorUnits: amountInMinorUnits,
        currency: currency,
        description: request.description,
        metadata: sharedMetadata,
        sourceMetadata: _extractNestedMap(sharedMetadata, 'sourceMetadata'),
        sourceData: _extractNestedMap(sharedMetadata, 'sourceData'),
        email: request.customerEmail,
        name: request.customerName,
      );

      final charge = result.charge;
      final source = result.source;
      final transactionId = result.chargeId ?? charge['id'] as String?;
      if (transactionId == null || transactionId.isEmpty) {
        throw PaymentGatewayException(
          'Omise PromptPay charge is missing a transaction identifier.',
        );
      }

      final metadata = <String, dynamic>{
        ...sharedMetadata,
        'gateway': 'omise',
        'channel': 'promptpay',
      };

      final status = _stringOrNull(charge['status']);
      if (status != null) {
        metadata['status'] = status;
      }
      final failureCode = _stringOrNull(charge['failure_code']);
      if (failureCode != null) {
        metadata['failureCode'] = failureCode;
      }
      final failureMessage = _stringOrNull(charge['failure_message']);
      if (failureMessage != null) {
        metadata['failureMessage'] = failureMessage;
      }
      final authorizeUri = _stringOrNull(charge['authorize_uri']);
      if (authorizeUri != null) {
        metadata['authorizeUri'] = authorizeUri;
      }
      if (charge['metadata'] is Map<String, dynamic>) {
        metadata['omiseMetadata'] = Map<String, dynamic>.from(
          charge['metadata'] as Map<String, dynamic>,
        );
      }
      if (source != null) {
        metadata['sourceId'] = _stringOrNull(source['id']);
        metadata['sourceType'] = source['type'];
      }

      final receiptUrl =
          _stringOrNull(charge['receipt_url']) ?? authorizeUri;

      return PaymentResult.success(
        transactionId: transactionId,
        receiptUrl: receiptUrl,
        metadata: metadata,
      );
    } on PaymentsServiceException catch (error) {
      throw PaymentGatewayException(error.message);
    } catch (error) {
      throw PaymentGatewayException(
        'Unexpected PromptPay payment error: $error',
      );
    }
  }

  @override
  Future<void> refundPayment(String transactionId, {double? amount}) async {
    throw PaymentGatewayException(
      'Refunds must be handled from the Omise dashboard for PromptPay charges.',
    );
  }
}

class MobileBankingPaymentAdapter extends PaymentGatewayAdapter {
  MobileBankingPaymentAdapter(
    PaymentGatewayConfig? config,
    this._paymentsService,
  ) : super(config);

  final PaymentsService _paymentsService;

  @override
  PaymentGatewayType get type => PaymentGatewayType.mobileBanking;

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    if (request.amount <= 0) {
      throw PaymentGatewayException('Amount must be greater than zero.');
    }

    final currency = request.currency.trim();
    if (currency.isEmpty) {
      throw PaymentGatewayException('Currency is required for mobile banking.');
    }

    final amountInMinorUnits = (request.amount * 100).round();
    final sharedMetadata = <String, dynamic>{
      'orderId': request.orderId,
      ...request.metadata,
    };
    sharedMetadata.remove('sourceMetadata');
    sharedMetadata.remove('sourceData');

    try {
      final result = await _paymentsService.createScbMobileBankingCharge(
        amountInMinorUnits: amountInMinorUnits,
        currency: currency,
        description: request.description,
        metadata: sharedMetadata,
        sourceMetadata: _extractNestedMap(sharedMetadata, 'sourceMetadata'),
        sourceData: _extractNestedMap(sharedMetadata, 'sourceData'),
      );

      final charge = result.charge;
      final source = result.source;
      final transactionId = result.chargeId ?? charge['id'] as String?;
      if (transactionId == null || transactionId.isEmpty) {
        throw PaymentGatewayException(
          'Omise mobile banking charge is missing a transaction identifier.',
        );
      }

      final metadata = <String, dynamic>{
        ...sharedMetadata,
        'gateway': 'omise',
        'channel': 'app_transfer',
      };

      final status = _stringOrNull(charge['status']);
      if (status != null) {
        metadata['status'] = status;
      }
      final authorizeUri = _stringOrNull(charge['authorize_uri']);
      if (authorizeUri != null) {
        metadata['authorizeUri'] = authorizeUri;
      }
      if (charge['metadata'] is Map<String, dynamic>) {
        metadata['omiseMetadata'] = Map<String, dynamic>.from(
          charge['metadata'] as Map<String, dynamic>,
        );
      }
      if (source != null) {
        metadata['sourceId'] = _stringOrNull(source['id']);
        metadata['sourceType'] = source['type'];
      }

      final receiptUrl =
          _stringOrNull(charge['receipt_url']) ?? authorizeUri;

      return PaymentResult.success(
        transactionId: transactionId,
        receiptUrl: receiptUrl,
        metadata: metadata,
      );
    } on PaymentsServiceException catch (error) {
      throw PaymentGatewayException(error.message);
    } catch (error) {
      throw PaymentGatewayException(
        'Unexpected mobile banking payment error: $error',
      );
    }
  }

  @override
  Future<void> refundPayment(String transactionId, {double? amount}) async {
    throw PaymentGatewayException(
      'Refunds for mobile banking charges must be processed via Omise.',
    );
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
    PaymentsService? paymentsService,
  })  : _configs = Map<PaymentGatewayType, PaymentGatewayConfig>.from(
          configs ?? const <PaymentGatewayType, PaymentGatewayConfig>{},
        ),
        _paymentsService = paymentsService ?? PaymentsService() {
    _adapter = _createAdapterFor(initialGateway);
  }

  final Map<PaymentGatewayType, PaymentGatewayConfig> _configs;
  final PaymentsService _paymentsService;
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
        return OmisePaymentAdapter(config, _paymentsService);
      case PaymentGatewayType.creditDebitCard:
        return CreditDebitCardPaymentAdapter(config, _paymentsService);
      case PaymentGatewayType.promptPay:
        return PromptPayPaymentAdapter(config, _paymentsService);
      case PaymentGatewayType.mobileBanking:
        return MobileBankingPaymentAdapter(config, _paymentsService);
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
  OmisePaymentAdapter(
    PaymentGatewayConfig? config,
    this._paymentsService,
  ) : super(config);

  final PaymentsService _paymentsService;

  @override
  PaymentGatewayType get type => PaymentGatewayType.omise;

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    if (request.amount <= 0) {
      throw PaymentGatewayException('Amount must be greater than zero.');
    }

    final currency = request.currency.trim();
    if (currency.isEmpty) {
      throw PaymentGatewayException('Currency is required for Omise payments.');
    }

    final config = this.config;
    final sourceType = (request.metadata['sourceType'] ??
        config?.additionalData['defaultSourceType']) as String?;
    if (sourceType == null || sourceType.isEmpty) {
      throw PaymentGatewayException(
        'Omise source type is not configured. Provide it in request metadata or configuration.',
      );
    }

    final amountInMinorUnits = (request.amount * 100).round();
    final sharedMetadata = <String, dynamic>{
      'orderId': request.orderId,
      ...request.metadata,
    };

    try {
      if (sourceType == 'promptpay') {
        final result = await _paymentsService.createPromptPayCharge(
          amountInMinorUnits: amountInMinorUnits,
          currency: currency,
          description: request.description,
          metadata: sharedMetadata,
          sourceMetadata: _extractNestedMap(sharedMetadata, 'sourceMetadata'),
          sourceData: _extractNestedMap(sharedMetadata, 'sourceData'),
          email: request.customerEmail,
          name: request.customerName,
        );

        return _buildSourceChargeResult(
          sharedMetadata: sharedMetadata,
          chargeResult: result,
          channel: 'promptpay',
        );
      }

      if (sourceType == 'mobile_banking_scb') {
        final result = await _paymentsService.createScbMobileBankingCharge(
          amountInMinorUnits: amountInMinorUnits,
          currency: currency,
          description: request.description,
          metadata: sharedMetadata,
          sourceMetadata: _extractNestedMap(sharedMetadata, 'sourceMetadata'),
          sourceData: _extractNestedMap(sharedMetadata, 'sourceData'),
        );

        return _buildSourceChargeResult(
          sharedMetadata: sharedMetadata,
          chargeResult: result,
          channel: 'app_transfer',
        );
      }

      throw PaymentGatewayException(
        'Unsupported Omise source type "$sourceType".',
      );
    } on PaymentsServiceException catch (error) {
      throw PaymentGatewayException(error.message);
    } catch (error) {
      throw PaymentGatewayException(
        'Unexpected Omise payment error: $error',
      );
    }
  }

  @override
  Future<void> refundPayment(String transactionId, {double? amount}) async {
    throw PaymentGatewayException(
      'Refunds for Omise charges must be issued from the Omise dashboard.',
    );
  }

  PaymentResult _buildSourceChargeResult({
    required Map<String, dynamic> sharedMetadata,
    required PaymentsChargeResult chargeResult,
    required String channel,
  }) {
    final charge = chargeResult.charge;
    final source = chargeResult.source;
    final transactionId = chargeResult.chargeId ?? charge['id'] as String?;
    if (transactionId == null || transactionId.isEmpty) {
      throw PaymentGatewayException(
        'Omise charge is missing a transaction identifier.',
      );
    }

    final metadata = <String, dynamic>{
      ...sharedMetadata,
      'gateway': 'omise',
      'channel': channel,
    };

    final status = _stringOrNull(charge['status']);
    if (status != null) {
      metadata['status'] = status;
    }
    final authorized = _coerceToBool(charge['authorized']);
    if (authorized != null) {
      metadata['authorized'] = authorized;
    }
    final failureCode = _stringOrNull(charge['failure_code']);
    if (failureCode != null) {
      metadata['failureCode'] = failureCode;
    }
    final failureMessage = _stringOrNull(charge['failure_message']);
    if (failureMessage != null) {
      metadata['failureMessage'] = failureMessage;
    }
    final authorizeUri = _stringOrNull(charge['authorize_uri']);
    if (authorizeUri != null) {
      metadata['authorizeUri'] = authorizeUri;
    }
    if (charge['metadata'] is Map<String, dynamic>) {
      metadata['omiseMetadata'] = Map<String, dynamic>.from(
        charge['metadata'] as Map<String, dynamic>,
      );
    }
    if (source != null) {
      metadata['sourceId'] = _stringOrNull(source['id']);
      metadata['sourceType'] = source['type'];
    }

    final receiptUrl =
        _stringOrNull(charge['receipt_url']) ?? authorizeUri;

    return PaymentResult.success(
      transactionId: transactionId,
      receiptUrl: receiptUrl,
      metadata: metadata,
    );
  }
}

String? _stringOrNull(dynamic value) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
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

Map<String, dynamic>? _extractNestedMap(
  Map<String, dynamic> metadata,
  String key,
) {
  final value = metadata[key];
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value as Map);
  }
  return null;
}
