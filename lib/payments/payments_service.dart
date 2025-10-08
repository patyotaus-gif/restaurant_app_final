import 'package:cloud_functions/cloud_functions.dart';

/// Lightweight wrapper around Cloud Functions endpoints that orchestrate Omise
/// payments. The functions expect amounts to be provided in the currency's
/// smallest unit (for example, satang for THB).
class PaymentsService {
  PaymentsService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  static const Duration _defaultTimeout = Duration(seconds: 30);

  final FirebaseFunctions _functions;

  /// Creates a card charge that supports 3-D Secure by delegating to the
  /// `createOmiseCardCharge3ds` callable Cloud Function.
  Future<PaymentsChargeResult> createCardCharge3ds({
    required int amountInMinorUnits,
    required String currency,
    required String cardToken,
    required String returnUri,
    String? description,
    Map<String, dynamic>? metadata,
    bool? capture,
    String? customerId,
  }) async {
    final payload = <String, dynamic>{
      'amount': amountInMinorUnits,
      'currency': currency,
      'cardToken': cardToken,
      'returnUri': returnUri,
      if (description != null) 'description': description,
      if (metadata != null) 'metadata': metadata,
      if (capture != null) 'capture': capture,
      if (customerId != null) 'customerId': customerId,
    };

    final data = await _invokeFunction('createOmiseCardCharge3ds', payload);
    return PaymentsChargeResult.fromJson(data);
  }

  /// Creates a PromptPay source + charge using the
  /// `createOmisePromptPayCharge` callable Cloud Function.
  Future<PaymentsChargeResult> createPromptPayCharge({
    required int amountInMinorUnits,
    required String currency,
    String? description,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? sourceMetadata,
    Map<String, dynamic>? sourceData,
    String? email,
    String? name,
    String? phoneNumber,
    bool? capture,
    String? customerId,
  }) async {
    final payload = <String, dynamic>{
      'amount': amountInMinorUnits,
      'currency': currency,
      if (description != null) 'description': description,
      if (metadata != null) 'metadata': metadata,
      if (sourceMetadata != null) 'sourceMetadata': sourceMetadata,
      if (sourceData != null) 'sourceData': sourceData,
      if (email != null) 'email': email,
      if (name != null) 'name': name,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (capture != null) 'capture': capture,
      if (customerId != null) 'customerId': customerId,
    };

    final data = await _invokeFunction('createOmisePromptPayCharge', payload);
    return PaymentsChargeResult.fromJson(data);
  }

  /// Creates a Siam Commercial Bank mobile banking charge via the
  /// `createOmiseMobileBankingCharge` callable Cloud Function. The
  /// implementation always requests the SCB banking channel.
  Future<PaymentsChargeResult> createScbMobileBankingCharge({
    required int amountInMinorUnits,
    required String currency,
    String? description,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? sourceMetadata,
    Map<String, dynamic>? sourceData,
    bool? capture,
    String? customerId,
  }) async {
    final payload = <String, dynamic>{
      'amount': amountInMinorUnits,
      'currency': currency,
      'bank': 'SCB',
      if (description != null) 'description': description,
      if (metadata != null) 'metadata': metadata,
      if (sourceMetadata != null) 'sourceMetadata': sourceMetadata,
      if (sourceData != null) 'sourceData': sourceData,
      if (capture != null) 'capture': capture,
      if (customerId != null) 'customerId': customerId,
    };

    final data =
        await _invokeFunction('createOmiseMobileBankingCharge', payload);
    return PaymentsChargeResult.fromJson(data);
  }

  Future<Map<String, dynamic>> _invokeFunction(
    String name,
    Map<String, dynamic> payload,
  ) async {
    try {
      final callable = _functions.httpsCallable(
        name,
        options: HttpsCallableOptions(timeout: _defaultTimeout),
      );
      final result = await callable.call<Map<String, dynamic>>(payload);
      final data = result.data;
      if (data == null) {
        throw const PaymentsServiceException('Cloud Functions returned null.');
      }
      return Map<String, dynamic>.from(data);
    } on FirebaseFunctionsException catch (error) {
      final message = error.message ??
          'Cloud Functions request "$name" failed with code ${error.code}';
      throw PaymentsServiceException(message, details: error.details);
    } catch (error) {
      throw PaymentsServiceException(
        'Unexpected error while calling "$name": $error',
      );
    }
  }
}

/// Data transfer object that wraps the Omise charge (and optional source)
/// returned by payment Cloud Functions.
class PaymentsChargeResult {
  const PaymentsChargeResult({
    required this.charge,
    this.source,
  });

  factory PaymentsChargeResult.fromJson(Map<String, dynamic> json) {
    final charge = json['charge'];
    if (charge is! Map) {
      throw const PaymentsServiceException(
        'Omise charge payload is missing or malformed.',
      );
    }

    final source = json['source'];
    return PaymentsChargeResult(
      charge: Map<String, dynamic>.from(charge as Map),
      source: source is Map
          ? Map<String, dynamic>.from(source as Map)
          : null,
    );
  }

  final Map<String, dynamic> charge;
  final Map<String, dynamic>? source;

  String? get chargeId => charge['id'] as String?;
  String? get authorizeUri => charge['authorize_uri'] as String?;
  String? get sourceId => source?['id'] as String?;
}

class PaymentsServiceException implements Exception {
  const PaymentsServiceException(this.message, {this.details});

  final String message;
  final Object? details;

  @override
  String toString() => 'PaymentsServiceException(message: $message, details: $details)';
}
