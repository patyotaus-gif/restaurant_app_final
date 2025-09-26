// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Restaurant POS';

  @override
  String get languagePickerLabel => 'Language';

  @override
  String get languagePickerSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageThai => 'Thai';

  @override
  String get pinLoginTitle => 'Enter PIN';

  @override
  String get pinLoginInstructions => 'Please enter your 4-digit PIN';

  @override
  String get pinLoginInvalidPin => 'Invalid PIN. Please try again.';

  @override
  String get pinLoginLoginButton => 'Login';

  @override
  String get checkoutCopyLink => 'Copy link';

  @override
  String get checkoutCopyLinkSuccess => 'Link copied to clipboard';

  @override
  String get checkoutAppliedPaymentsTitle => 'Applied Payments';

  @override
  String get checkoutPaymentUnknownMethod => 'Unknown';

  @override
  String checkoutPaymentReference(Object reference) {
    return 'Ref: $reference';
  }

  @override
  String get ingredientDialogCreateTitle => 'Add ingredient';

  @override
  String get ingredientDialogEditTitle => 'Edit ingredient';

  @override
  String get ingredientFieldNameLabel => 'Ingredient name';

  @override
  String get ingredientFieldNameValidation => 'Please enter a name';

  @override
  String get ingredientFieldUnitLabel => 'Unit (e.g. kg, g, pcs)';

  @override
  String get ingredientFieldUnitValidation => 'Please enter a unit';

  @override
  String get ingredientFieldStockLabel => 'Stock quantity';

  @override
  String get ingredientFieldStockValidation => 'Please enter a quantity';

  @override
  String get ingredientFieldCostLabel => 'Average cost per unit';

  @override
  String get ingredientFieldCostValidation => 'Please enter a cost';

  @override
  String get ingredientFieldThresholdLabel => 'Low stock threshold';

  @override
  String get ingredientFieldThresholdValidation => 'Please enter a threshold';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get ingredientDeleteTitle => 'Delete ingredient';

  @override
  String get ingredientDeleteMessage =>
      'Are you sure you want to delete this item?';

  @override
  String get ingredientPageTitle => 'Ingredient inventory';

  @override
  String get ingredientAddPurchaseOrderTooltip => 'Add purchase order';

  @override
  String ingredientListError(Object message) {
    return 'Error: $message';
  }

  @override
  String get ingredientListEmpty => 'No ingredients found';

  @override
  String ingredientSummary(Object quantity, Object unit, Object avgCost) {
    return '$quantity $unit (Avg. cost: $avgCost)';
  }

  @override
  String get ingredientFabTooltip => 'Add ingredient';

  @override
  String get unitKilogram => 'kg';

  @override
  String get unitGram => 'g';

  @override
  String get unitLiter => 'L';

  @override
  String get unitMilliliter => 'mL';

  @override
  String get unitPiece => 'pc';

  @override
  String valueWithUnit(Object value, Object unit) {
    return '$value $unit';
  }
}
