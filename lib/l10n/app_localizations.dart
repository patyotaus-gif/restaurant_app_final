import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_th.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('th'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Restaurant POS'**
  String get appTitle;

  /// No description provided for @languagePickerLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languagePickerLabel;

  /// No description provided for @languagePickerSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languagePickerSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageThai.
  ///
  /// In en, this message translates to:
  /// **'Thai'**
  String get languageThai;

  /// No description provided for @pinLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get pinLoginTitle;

  /// No description provided for @pinLoginInstructions.
  ///
  /// In en, this message translates to:
  /// **'Please enter your 4-digit PIN'**
  String get pinLoginInstructions;

  /// No description provided for @pinLoginInvalidPin.
  ///
  /// In en, this message translates to:
  /// **'Invalid PIN. Please try again.'**
  String get pinLoginInvalidPin;

  /// No description provided for @pinLoginLoginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get pinLoginLoginButton;

  /// No description provided for @checkoutCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get checkoutCopyLink;

  /// No description provided for @checkoutCopyLinkSuccess.
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard'**
  String get checkoutCopyLinkSuccess;

  /// No description provided for @checkoutAppliedPaymentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Applied Payments'**
  String get checkoutAppliedPaymentsTitle;

  /// No description provided for @checkoutPaymentUnknownMethod.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get checkoutPaymentUnknownMethod;

  /// No description provided for @checkoutPaymentReference.
  ///
  /// In en, this message translates to:
  /// **'Ref: {reference}'**
  String checkoutPaymentReference(Object reference);

  /// No description provided for @ingredientDialogCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Add ingredient'**
  String get ingredientDialogCreateTitle;

  /// No description provided for @ingredientDialogEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit ingredient'**
  String get ingredientDialogEditTitle;

  /// No description provided for @ingredientFieldNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Ingredient name'**
  String get ingredientFieldNameLabel;

  /// No description provided for @ingredientFieldNameValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get ingredientFieldNameValidation;

  /// No description provided for @ingredientFieldUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit (e.g. kg, g, pcs)'**
  String get ingredientFieldUnitLabel;

  /// No description provided for @ingredientFieldUnitValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter a unit'**
  String get ingredientFieldUnitValidation;

  /// No description provided for @ingredientFieldStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Stock quantity'**
  String get ingredientFieldStockLabel;

  /// No description provided for @ingredientFieldStockValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter a quantity'**
  String get ingredientFieldStockValidation;

  /// No description provided for @ingredientFieldCostLabel.
  ///
  /// In en, this message translates to:
  /// **'Average cost per unit'**
  String get ingredientFieldCostLabel;

  /// No description provided for @ingredientFieldCostValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter a cost'**
  String get ingredientFieldCostValidation;

  /// No description provided for @ingredientFieldThresholdLabel.
  ///
  /// In en, this message translates to:
  /// **'Low stock threshold'**
  String get ingredientFieldThresholdLabel;

  /// No description provided for @ingredientFieldThresholdValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter a threshold'**
  String get ingredientFieldThresholdValidation;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @ingredientDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete ingredient'**
  String get ingredientDeleteTitle;

  /// No description provided for @ingredientDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this item?'**
  String get ingredientDeleteMessage;

  /// No description provided for @ingredientPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Ingredient inventory'**
  String get ingredientPageTitle;

  /// No description provided for @ingredientAddPurchaseOrderTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add purchase order'**
  String get ingredientAddPurchaseOrderTooltip;

  /// No description provided for @ingredientListError.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String ingredientListError(Object message);

  /// No description provided for @ingredientListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No ingredients found'**
  String get ingredientListEmpty;

  /// No description provided for @ingredientSummary.
  ///
  /// In en, this message translates to:
  /// **'{quantity} {unit} (Avg. cost: {avgCost})'**
  String ingredientSummary(Object quantity, Object unit, Object avgCost);

  /// No description provided for @ingredientFabTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add ingredient'**
  String get ingredientFabTooltip;

  /// No description provided for @unitKilogram.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get unitKilogram;

  /// No description provided for @unitGram.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get unitGram;

  /// No description provided for @unitLiter.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get unitLiter;

  /// No description provided for @unitMilliliter.
  ///
  /// In en, this message translates to:
  /// **'mL'**
  String get unitMilliliter;

  /// No description provided for @unitPiece.
  ///
  /// In en, this message translates to:
  /// **'pc'**
  String get unitPiece;

  /// No description provided for @valueWithUnit.
  ///
  /// In en, this message translates to:
  /// **'{value} {unit}'**
  String valueWithUnit(Object value, Object unit);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'th'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'th':
      return AppLocalizationsTh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
