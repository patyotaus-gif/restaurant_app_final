import 'store_model.dart';
class StoreReceiptDetails {
  final String name;
  final String? branch;
  final String? taxId;
  final String? address;
  final String? phone;
  final String? email;

  const StoreReceiptDetails({
    required this.name,
    this.branch,
    this.taxId,
    this.address,
    this.phone,
    this.email,
  });

  factory StoreReceiptDetails.fromStore(Store store, {String? branch}) {
    return StoreReceiptDetails(
      name: store.name,
      branch: branch,
      taxId: store.taxId,
      address: store.address,
      phone: store.phone,
      email: store.email,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (branch != null) 'branch': branch,
      if (taxId != null) 'taxId': taxId,
      if (address != null) 'address': address,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
    };
  }
}

class TaxInvoiceDetails {
  final String? customerName;
  final String? taxId;
  final String? address;
  final String? email;
  final String? phone;

  const TaxInvoiceDetails({
    this.customerName,
    this.taxId,
    this.address,
    this.email,
    this.phone,
  });

  bool get hasData =>
      (customerName != null && customerName!.isNotEmpty) ||
      (taxId != null && taxId!.isNotEmpty) ||
      (address != null && address!.isNotEmpty) ||
      (email != null && email!.isNotEmpty) ||
      (phone != null && phone!.isNotEmpty);

  Map<String, dynamic> toMap() {
    return {
      if (customerName != null && customerName!.isNotEmpty)
        'customerName': customerName,
      if (taxId != null && taxId!.isNotEmpty) 'taxId': taxId,
      if (address != null && address!.isNotEmpty) 'address': address,
      if (email != null && email!.isNotEmpty) 'email': email,
      if (phone != null && phone!.isNotEmpty) 'phone': phone,
    };
  }
}
