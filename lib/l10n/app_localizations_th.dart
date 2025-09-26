// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get appTitle => 'ระบบ POS ร้านอาหาร';

  @override
  String get languagePickerLabel => 'ภาษา';

  @override
  String get languagePickerSystem => 'ตามค่าระบบ';

  @override
  String get languageEnglish => 'อังกฤษ';

  @override
  String get languageThai => 'ไทย';

  @override
  String get pinLoginTitle => 'กรอกรหัส PIN';

  @override
  String get pinLoginInstructions => 'กรุณากรอกรหัส PIN 4 หลัก';

  @override
  String get pinLoginInvalidPin => 'รหัส PIN ไม่ถูกต้อง กรุณาลองอีกครั้ง';

  @override
  String get pinLoginLoginButton => 'เข้าสู่ระบบ';

  @override
  String get checkoutCopyLink => 'คัดลอกลิงก์';

  @override
  String get checkoutCopyLinkSuccess => 'คัดลอกลิงก์เรียบร้อยแล้ว';

  @override
  String get checkoutAppliedPaymentsTitle => 'รายการชำระเงินที่ใช้';

  @override
  String get checkoutPaymentUnknownMethod => 'ไม่ทราบ';

  @override
  String checkoutPaymentReference(Object reference) {
    return 'อ้างอิง: $reference';
  }

  @override
  String get ingredientDialogCreateTitle => 'เพิ่มวัตถุดิบ';

  @override
  String get ingredientDialogEditTitle => 'แก้ไขวัตถุดิบ';

  @override
  String get ingredientFieldNameLabel => 'ชื่อวัตถุดิบ';

  @override
  String get ingredientFieldNameValidation => 'กรุณากรอกชื่อ';

  @override
  String get ingredientFieldUnitLabel => 'หน่วยนับ (เช่น กก., กรัม, ชิ้น)';

  @override
  String get ingredientFieldUnitValidation => 'กรุณากรอกหน่วยนับ';

  @override
  String get ingredientFieldStockLabel => 'จำนวนคงเหลือ';

  @override
  String get ingredientFieldStockValidation => 'กรุณากรอกจำนวน';

  @override
  String get ingredientFieldCostLabel => 'ต้นทุนเฉลี่ยต่อหน่วย';

  @override
  String get ingredientFieldCostValidation => 'กรุณากรอกต้นทุน';

  @override
  String get ingredientFieldThresholdLabel => 'จุดเตือนสต็อกต่ำ';

  @override
  String get ingredientFieldThresholdValidation => 'กรุณากรอกจุดเตือน';

  @override
  String get commonCancel => 'ยกเลิก';

  @override
  String get commonSave => 'บันทึก';

  @override
  String get commonDelete => 'ลบ';

  @override
  String get ingredientDeleteTitle => 'ยืนยันการลบ';

  @override
  String get ingredientDeleteMessage => 'คุณต้องการลบรายการนี้หรือไม่';

  @override
  String get ingredientPageTitle => 'จัดการสต็อกวัตถุดิบ';

  @override
  String get ingredientAddPurchaseOrderTooltip => 'สร้างใบสั่งซื้อ';

  @override
  String ingredientListError(Object message) {
    return 'เกิดข้อผิดพลาด: $message';
  }

  @override
  String get ingredientListEmpty => 'ยังไม่มีวัตถุดิบในระบบ';

  @override
  String ingredientSummary(Object quantity, Object unit, Object avgCost) {
    return '$quantity $unit (ต้นทุนเฉลี่ย: $avgCost)';
  }

  @override
  String get ingredientFabTooltip => 'เพิ่มวัตถุดิบ';

  @override
  String get unitKilogram => 'กก.';

  @override
  String get unitGram => 'กรัม';

  @override
  String get unitLiter => 'ลิตร';

  @override
  String get unitMilliliter => 'มิลลิลิตร';

  @override
  String get unitPiece => 'ชิ้น';

  @override
  String valueWithUnit(Object value, Object unit) {
    return '$value $unit';
  }
}
