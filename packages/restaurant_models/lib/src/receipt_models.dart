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
}
