import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('th'),
  ];

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'Restaurant POS',
      'languagePickerLabel': 'Language',
      'languagePickerSystem': 'System default',
      'languageEnglish': 'English',
      'languageThai': 'Thai',
      'pinLoginTitle': 'Enter PIN',
      'pinLoginInstructions': 'Please enter your 4-digit PIN',
      'pinLoginInvalidPin': 'Invalid PIN. Please try again.',
      'pinLoginLoginButton': 'Login',
      'checkoutCopyLink': 'Copy link',
      'checkoutCopyLinkSuccess': 'Link copied to clipboard',
      'checkoutAppliedPaymentsTitle': 'Applied Payments',
      'checkoutPaymentUnknownMethod': 'Unknown',
      'checkoutPaymentReference': 'Ref: {reference}',
      'ingredientDialogCreateTitle': 'Add ingredient',
      'ingredientDialogEditTitle': 'Edit ingredient',
      'ingredientFieldNameLabel': 'Ingredient name',
      'ingredientFieldNameValidation': 'Please enter a name',
      'ingredientFieldUnitLabel': 'Unit (e.g. kg, g, pcs)',
      'ingredientFieldUnitValidation': 'Please enter a unit',
      'ingredientFieldStockLabel': 'Stock quantity',
      'ingredientFieldStockValidation': 'Please enter a quantity',
      'ingredientFieldCostLabel': 'Average cost per unit',
      'ingredientFieldCostValidation': 'Please enter a cost',
      'ingredientFieldThresholdLabel': 'Low stock threshold',
      'ingredientFieldThresholdValidation': 'Please enter a threshold',
      'commonCancel': 'Cancel',
      'commonSave': 'Save',
      'commonDelete': 'Delete',
      'ingredientDeleteTitle': 'Delete ingredient',
      'ingredientDeleteMessage':
          'Are you sure you want to delete this item?',
      'ingredientPageTitle': 'Ingredient inventory',
      'ingredientAddPurchaseOrderTooltip': 'Add purchase order',
      'ingredientListError': 'Error: {message}',
      'ingredientListEmpty': 'No ingredients found',
      'ingredientSummary': '{quantity} {unit} (Avg. cost: {avgCost})',
      'ingredientFabTooltip': 'Add ingredient',
      'unitKilogram': 'kg',
      'unitGram': 'g',
      'unitLiter': 'L',
      'unitMilliliter': 'mL',
      'unitPiece': 'pc',
      'valueWithUnit': '{value} {unit}',
      'menuCategorySoftDrinks': 'SOFT DRINKS',
      'menuCategoryBeers': 'BEERS',
      'menuCategoryHotDrinks': 'Hot Drinks',
      'menuCategoryMunchies': 'Munchies',
      'menuCategoryTheFish': 'The Fish',
      'menuCategoryNoodleDishes': 'Noodle Dishes',
      'menuCategoryRiceDishes': 'Rice Dishes',
      'menuCategoryNoodleSoups': 'Noodle Soups',
      'menuCategoryTheSalad': 'The Salad',
      'menuCategoryDessert': 'Dessert',
      'menuCategoryEmpty': 'No items in the "{category}" category.',
    },
    'th': {
      'appTitle': 'ระบบ POS ร้านอาหาร',
      'languagePickerLabel': 'ภาษา',
      'languagePickerSystem': 'ตามค่าระบบ',
      'languageEnglish': 'อังกฤษ',
      'languageThai': 'ไทย',
      'pinLoginTitle': 'กรอกรหัส PIN',
      'pinLoginInstructions': 'กรุณากรอกรหัส PIN 4 หลัก',
      'pinLoginInvalidPin': 'รหัส PIN ไม่ถูกต้อง กรุณาลองอีกครั้ง',
      'pinLoginLoginButton': 'เข้าสู่ระบบ',
      'checkoutCopyLink': 'คัดลอกลิงก์',
      'checkoutCopyLinkSuccess': 'คัดลอกลิงก์เรียบร้อยแล้ว',
      'checkoutAppliedPaymentsTitle': 'รายการชำระเงินที่ใช้',
      'checkoutPaymentUnknownMethod': 'ไม่ทราบ',
      'checkoutPaymentReference': 'อ้างอิง: {reference}',
      'ingredientDialogCreateTitle': 'เพิ่มวัตถุดิบ',
      'ingredientDialogEditTitle': 'แก้ไขวัตถุดิบ',
      'ingredientFieldNameLabel': 'ชื่อวัตถุดิบ',
      'ingredientFieldNameValidation': 'กรุณากรอกชื่อ',
      'ingredientFieldUnitLabel': 'หน่วยนับ (เช่น กก., กรัม, ชิ้น)',
      'ingredientFieldUnitValidation': 'กรุณากรอกหน่วยนับ',
      'ingredientFieldStockLabel': 'จำนวนคงเหลือ',
      'ingredientFieldStockValidation': 'กรุณากรอกจำนวน',
      'ingredientFieldCostLabel': 'ต้นทุนเฉลี่ยต่อหน่วย',
      'ingredientFieldCostValidation': 'กรุณากรอกต้นทุน',
      'ingredientFieldThresholdLabel': 'จุดเตือนสต็อกต่ำ',
      'ingredientFieldThresholdValidation': 'กรุณากรอกจุดเตือน',
      'commonCancel': 'ยกเลิก',
      'commonSave': 'บันทึก',
      'commonDelete': 'ลบ',
      'ingredientDeleteTitle': 'ยืนยันการลบ',
      'ingredientDeleteMessage': 'คุณต้องการลบรายการนี้หรือไม่',
      'ingredientPageTitle': 'จัดการสต็อกวัตถุดิบ',
      'ingredientAddPurchaseOrderTooltip': 'สร้างใบสั่งซื้อ',
      'ingredientListError': 'เกิดข้อผิดพลาด: {message}',
      'ingredientListEmpty': 'ยังไม่มีวัตถุดิบในระบบ',
      'ingredientSummary': '{quantity} {unit} (ต้นทุนเฉลี่ย: {avgCost})',
      'ingredientFabTooltip': 'เพิ่มวัตถุดิบ',
      'unitKilogram': 'กก.',
      'unitGram': 'กรัม',
      'unitLiter': 'ลิตร',
      'unitMilliliter': 'มิลลิลิตร',
      'unitPiece': 'ชิ้น',
      'valueWithUnit': '{value} {unit}',
      'menuCategorySoftDrinks': 'เครื่องดื่มเย็น',
      'menuCategoryBeers': 'เบียร์',
      'menuCategoryHotDrinks': 'เครื่องดื่มร้อน',
      'menuCategoryMunchies': 'ของทานเล่น',
      'menuCategoryTheFish': 'เมนูปลา',
      'menuCategoryNoodleDishes': 'เมนูก๋วยเตี๋ยว',
      'menuCategoryRiceDishes': 'เมนูข้าว',
      'menuCategoryNoodleSoups': 'ก๋วยเตี๋ยวน้ำ',
      'menuCategoryTheSalad': 'เมนูสลัด',
      'menuCategoryDessert': 'ของหวาน',
      'menuCategoryEmpty': 'ยังไม่มีรายการในหมวด "{category}"',
    },
  };

  String _resolve(String key) {
    final languageCode = locale.languageCode;
    final languageValues =
        _localizedValues[languageCode] ?? _localizedValues['en'];
    return (languageValues?[key] ?? _localizedValues['en']![key]) ?? '';
  }

  String _format(String key, Map<String, String> values) {
    var template = _resolve(key);
    for (final entry in values.entries) {
      template = template.replaceAll('{${entry.key}}', entry.value);
    }
    return template;
  }

  String get appTitle => _resolve('appTitle');
  String get languagePickerLabel => _resolve('languagePickerLabel');
  String get languagePickerSystem => _resolve('languagePickerSystem');
  String get languageEnglish => _resolve('languageEnglish');
  String get languageThai => _resolve('languageThai');
  String get pinLoginTitle => _resolve('pinLoginTitle');
  String get pinLoginInstructions => _resolve('pinLoginInstructions');
  String get pinLoginInvalidPin => _resolve('pinLoginInvalidPin');
  String get pinLoginLoginButton => _resolve('pinLoginLoginButton');
  String get checkoutCopyLink => _resolve('checkoutCopyLink');
  String get checkoutCopyLinkSuccess =>
      _resolve('checkoutCopyLinkSuccess');
  String get checkoutAppliedPaymentsTitle =>
      _resolve('checkoutAppliedPaymentsTitle');
  String get checkoutPaymentUnknownMethod =>
      _resolve('checkoutPaymentUnknownMethod');
  String checkoutPaymentReference(String reference) =>
      _format('checkoutPaymentReference', {'reference': reference});
  String get ingredientDialogCreateTitle =>
      _resolve('ingredientDialogCreateTitle');
  String get ingredientDialogEditTitle =>
      _resolve('ingredientDialogEditTitle');
  String get ingredientFieldNameLabel =>
      _resolve('ingredientFieldNameLabel');
  String get ingredientFieldNameValidation =>
      _resolve('ingredientFieldNameValidation');
  String get ingredientFieldUnitLabel =>
      _resolve('ingredientFieldUnitLabel');
  String get ingredientFieldUnitValidation =>
      _resolve('ingredientFieldUnitValidation');
  String get ingredientFieldStockLabel =>
      _resolve('ingredientFieldStockLabel');
  String get ingredientFieldStockValidation =>
      _resolve('ingredientFieldStockValidation');
  String get ingredientFieldCostLabel =>
      _resolve('ingredientFieldCostLabel');
  String get ingredientFieldCostValidation =>
      _resolve('ingredientFieldCostValidation');
  String get ingredientFieldThresholdLabel =>
      _resolve('ingredientFieldThresholdLabel');
  String get ingredientFieldThresholdValidation =>
      _resolve('ingredientFieldThresholdValidation');
  String get commonCancel => _resolve('commonCancel');
  String get commonSave => _resolve('commonSave');
  String get commonDelete => _resolve('commonDelete');
  String get ingredientDeleteTitle => _resolve('ingredientDeleteTitle');
  String get ingredientDeleteMessage =>
      _resolve('ingredientDeleteMessage');
  String get ingredientPageTitle => _resolve('ingredientPageTitle');
  String get ingredientAddPurchaseOrderTooltip =>
      _resolve('ingredientAddPurchaseOrderTooltip');
  String ingredientListError(String message) =>
      _format('ingredientListError', {'message': message});
  String get ingredientListEmpty => _resolve('ingredientListEmpty');
  String ingredientSummary(String quantity, String unit, String avgCost) =>
      _format('ingredientSummary', {
        'quantity': quantity,
        'unit': unit,
        'avgCost': avgCost,
      });
  String get ingredientFabTooltip => _resolve('ingredientFabTooltip');
  String get unitKilogram => _resolve('unitKilogram');
  String get unitGram => _resolve('unitGram');
  String get unitLiter => _resolve('unitLiter');
  String get unitMilliliter => _resolve('unitMilliliter');
  String get unitPiece => _resolve('unitPiece');
  String valueWithUnit(String value, String unit) =>
      _format('valueWithUnit', {'value': value, 'unit': unit});
  String get menuCategorySoftDrinks => _resolve('menuCategorySoftDrinks');
  String get menuCategoryBeers => _resolve('menuCategoryBeers');
  String get menuCategoryHotDrinks => _resolve('menuCategoryHotDrinks');
  String get menuCategoryMunchies => _resolve('menuCategoryMunchies');
  String get menuCategoryTheFish => _resolve('menuCategoryTheFish');
  String get menuCategoryNoodleDishes =>
      _resolve('menuCategoryNoodleDishes');
  String get menuCategoryRiceDishes => _resolve('menuCategoryRiceDishes');
  String get menuCategoryNoodleSoups =>
      _resolve('menuCategoryNoodleSoups');
  String get menuCategoryTheSalad => _resolve('menuCategoryTheSalad');
  String get menuCategoryDessert => _resolve('menuCategoryDessert');
  String menuCategoryEmpty(String category) =>
      _format('menuCategoryEmpty', {'category': category});
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales
        .any((supported) => supported.languageCode == locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
