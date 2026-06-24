import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyLocale = 'app_locale';
const String _keyThemeMode = 'app_theme_mode';
const String _keyShopName = 'shop_name';
const String _keyShopAddress = 'shop_address';
const String _keyShopPhone = 'shop_phone';
const String _keyDefaultCopies = 'default_copies';

// Receipt basic settings
const String _keyTextOnlyPrint = 'text_only_print';
const String _keySortItemsAlphabetical = 'sort_items_alphabetical';
const String _keyPrintCustomerInfo = 'print_customer_info';
const String _keyPrintSalesmanName = 'print_salesman_name';
const String _keyEnablePaymentInfo = 'enable_payment_info';
const String _keyEnableTableBorder = 'enable_table_border';
const String _keyEnableMinimalInfo = 'enable_minimal_info';
const String _keyShowTimeOnReceipt = 'show_time_on_receipt';
const String _keyShowTaxIncludedPrice = 'show_tax_included_price';
const String _keyPrintFontSize = 'print_font_size';
const String _keyPrintLineHeight = 'print_line_height';
const String _keyInvoiceIdPrefix = 'invoice_id_prefix';
const String _keyLastInvoiceId = 'last_invoice_id';
const String _keyLastOrderId = 'last_order_id';
const String _keyCustomTaxLabel = 'custom_tax_label';
const String _keyCustomPayableLabel = 'custom_payable_label';
const String _keyAttachQrCode = 'attach_qr_code';
const String _keyQrCodeData = 'qr_code_data';

// Receipt template & titles
const String _keyReceiptTemplate = 'receipt_template';
const String _keyReceiptTitle = 'receipt_title';
const String _keyReceiptFooter = 'receipt_footer';

enum AppThemeMode { light, dark, system }

class AppSettingsState {
  final Locale locale;
  final AppThemeMode themeMode;
  final String shopName;
  final String shopAddress;
  final String shopPhone;
  final int defaultCopies;

  // Receipt basic settings
  final bool textOnlyPrint;
  final bool sortItemsAlphabetical;
  final bool printCustomerInfo;
  final bool printSalesmanName;
  final bool enablePaymentInfo;
  final bool enableTableBorder;
  final bool enableMinimalInfo;
  final bool showTimeOnReceipt;
  final bool showTaxIncludedPrice;
  final double printFontSize;
  final double printLineHeight;
  final String invoiceIdPrefix;
  final int lastInvoiceId;
  final int lastOrderId;
  final String customTaxLabel;
  final String customPayableLabel;
  final bool attachQrCode;
  final String qrCodeData;

  // Template & titles
  final int receiptTemplate;
  final String receiptTitle;
  final String receiptFooter;

  const AppSettingsState({
    this.locale = const Locale('bn', 'BD'),
    this.themeMode = AppThemeMode.system,
    this.shopName = 'আমার দোকান',
    this.shopAddress = '',
    this.shopPhone = '',
    this.defaultCopies = 2,
    this.textOnlyPrint = false,
    this.sortItemsAlphabetical = false,
    this.printCustomerInfo = true,
    this.printSalesmanName = false,
    this.enablePaymentInfo = true,
    this.enableTableBorder = true,
    this.enableMinimalInfo = false,
    this.showTimeOnReceipt = true,
    this.showTaxIncludedPrice = false,
    this.printFontSize = 0.5,
    this.printLineHeight = 0.5,
    this.invoiceIdPrefix = '',
    this.lastInvoiceId = 1,
    this.lastOrderId = 1,
    this.customTaxLabel = 'ট্যাক্স',
    this.customPayableLabel = 'পরিশোধযোগ্য',
    this.attachQrCode = false,
    this.qrCodeData = '',
    this.receiptTemplate = 0,
    this.receiptTitle = 'বিক্রয় চালান',
    this.receiptFooter = '',
  });

  bool get isBangla => locale.languageCode == 'bn';

  ThemeMode get flutterThemeMode {
    switch (themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  AppSettingsState copyWith({
    Locale? locale,
    AppThemeMode? themeMode,
    String? shopName,
    String? shopAddress,
    String? shopPhone,
    int? defaultCopies,
    bool? textOnlyPrint,
    bool? sortItemsAlphabetical,
    bool? printCustomerInfo,
    bool? printSalesmanName,
    bool? enablePaymentInfo,
    bool? enableTableBorder,
    bool? enableMinimalInfo,
    bool? showTimeOnReceipt,
    bool? showTaxIncludedPrice,
    double? printFontSize,
    double? printLineHeight,
    String? invoiceIdPrefix,
    int? lastInvoiceId,
    int? lastOrderId,
    String? customTaxLabel,
    String? customPayableLabel,
    bool? attachQrCode,
    String? qrCodeData,
    int? receiptTemplate,
    String? receiptTitle,
    String? receiptFooter,
  }) {
    return AppSettingsState(
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
      shopName: shopName ?? this.shopName,
      shopAddress: shopAddress ?? this.shopAddress,
      shopPhone: shopPhone ?? this.shopPhone,
      defaultCopies: defaultCopies ?? this.defaultCopies,
      textOnlyPrint: textOnlyPrint ?? this.textOnlyPrint,
      sortItemsAlphabetical: sortItemsAlphabetical ?? this.sortItemsAlphabetical,
      printCustomerInfo: printCustomerInfo ?? this.printCustomerInfo,
      printSalesmanName: printSalesmanName ?? this.printSalesmanName,
      enablePaymentInfo: enablePaymentInfo ?? this.enablePaymentInfo,
      enableTableBorder: enableTableBorder ?? this.enableTableBorder,
      enableMinimalInfo: enableMinimalInfo ?? this.enableMinimalInfo,
      showTimeOnReceipt: showTimeOnReceipt ?? this.showTimeOnReceipt,
      showTaxIncludedPrice: showTaxIncludedPrice ?? this.showTaxIncludedPrice,
      printFontSize: printFontSize ?? this.printFontSize,
      printLineHeight: printLineHeight ?? this.printLineHeight,
      invoiceIdPrefix: invoiceIdPrefix ?? this.invoiceIdPrefix,
      lastInvoiceId: lastInvoiceId ?? this.lastInvoiceId,
      lastOrderId: lastOrderId ?? this.lastOrderId,
      customTaxLabel: customTaxLabel ?? this.customTaxLabel,
      customPayableLabel: customPayableLabel ?? this.customPayableLabel,
      attachQrCode: attachQrCode ?? this.attachQrCode,
      qrCodeData: qrCodeData ?? this.qrCodeData,
      receiptTemplate: receiptTemplate ?? this.receiptTemplate,
      receiptTitle: receiptTitle ?? this.receiptTitle,
      receiptFooter: receiptFooter ?? this.receiptFooter,
    );
  }
}

class AppSettingsCubit extends Cubit<AppSettingsState> {
  AppSettingsCubit() : super(const AppSettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final localeCode = prefs.getString(_keyLocale);
    final themeIndex = prefs.getInt(_keyThemeMode);

    Locale locale = const Locale('bn', 'BD');
    if (localeCode == 'en') {
      locale = const Locale('en', 'US');
    } else if (localeCode == 'bn') {
      locale = const Locale('bn', 'BD');
    }

    AppThemeMode mode = AppThemeMode.system;
    if (themeIndex != null && themeIndex >= 0 && themeIndex <= 2) {
      mode = AppThemeMode.values[themeIndex];
    }

    emit(state.copyWith(
      locale: locale,
      themeMode: mode,
      shopName: prefs.getString(_keyShopName) ?? 'আমার দোকান',
      shopAddress: prefs.getString(_keyShopAddress) ?? '',
      shopPhone: prefs.getString(_keyShopPhone) ?? '',
      defaultCopies: prefs.getInt(_keyDefaultCopies) ?? 2,
      textOnlyPrint: prefs.getBool(_keyTextOnlyPrint) ?? false,
      sortItemsAlphabetical: prefs.getBool(_keySortItemsAlphabetical) ?? false,
      printCustomerInfo: prefs.getBool(_keyPrintCustomerInfo) ?? true,
      printSalesmanName: prefs.getBool(_keyPrintSalesmanName) ?? false,
      enablePaymentInfo: prefs.getBool(_keyEnablePaymentInfo) ?? true,
      enableTableBorder: prefs.getBool(_keyEnableTableBorder) ?? true,
      enableMinimalInfo: prefs.getBool(_keyEnableMinimalInfo) ?? false,
      showTimeOnReceipt: prefs.getBool(_keyShowTimeOnReceipt) ?? true,
      showTaxIncludedPrice: prefs.getBool(_keyShowTaxIncludedPrice) ?? false,
      printFontSize: (prefs.getInt(_keyPrintFontSize) ?? 50) / 100.0,
      printLineHeight: (prefs.getInt(_keyPrintLineHeight) ?? 50) / 100.0,
      invoiceIdPrefix: prefs.getString(_keyInvoiceIdPrefix) ?? '',
      lastInvoiceId: prefs.getInt(_keyLastInvoiceId) ?? 1,
      lastOrderId: prefs.getInt(_keyLastOrderId) ?? 1,
      customTaxLabel: prefs.getString(_keyCustomTaxLabel) ?? 'ট্যাক্স',
      customPayableLabel: prefs.getString(_keyCustomPayableLabel) ?? 'পরিশোধযোগ্য',
      attachQrCode: prefs.getBool(_keyAttachQrCode) ?? false,
      qrCodeData: prefs.getString(_keyQrCodeData) ?? '',
      receiptTemplate: prefs.getInt(_keyReceiptTemplate) ?? 0,
      receiptTitle: prefs.getString(_keyReceiptTitle) ?? 'বিক্রয় চালান',
      receiptFooter: prefs.getString(_keyReceiptFooter) ?? '',
    ));
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, locale.languageCode);
    emit(state.copyWith(locale: locale));
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeMode, mode.index);
    emit(state.copyWith(themeMode: mode));
  }

  Future<void> setShopInfo({
    required String name,
    required String address,
    required String phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyShopName, name);
    await prefs.setString(_keyShopAddress, address);
    await prefs.setString(_keyShopPhone, phone);
    emit(state.copyWith(shopName: name, shopAddress: address, shopPhone: phone));
  }

  Future<void> setDefaultCopies(int copies) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDefaultCopies, copies);
    emit(state.copyWith(defaultCopies: copies));
  }

  Future<void> setReceiptSettings({
    bool? textOnlyPrint,
    bool? sortItemsAlphabetical,
    bool? printCustomerInfo,
    bool? printSalesmanName,
    bool? enablePaymentInfo,
    bool? enableTableBorder,
    bool? enableMinimalInfo,
    bool? showTimeOnReceipt,
    bool? showTaxIncludedPrice,
    double? printFontSize,
    double? printLineHeight,
    String? invoiceIdPrefix,
    int? lastInvoiceId,
    int? lastOrderId,
    String? customTaxLabel,
    String? customPayableLabel,
    bool? attachQrCode,
    String? qrCodeData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (textOnlyPrint != null) await prefs.setBool(_keyTextOnlyPrint, textOnlyPrint);
    if (sortItemsAlphabetical != null) await prefs.setBool(_keySortItemsAlphabetical, sortItemsAlphabetical);
    if (printCustomerInfo != null) await prefs.setBool(_keyPrintCustomerInfo, printCustomerInfo);
    if (printSalesmanName != null) await prefs.setBool(_keyPrintSalesmanName, printSalesmanName);
    if (enablePaymentInfo != null) await prefs.setBool(_keyEnablePaymentInfo, enablePaymentInfo);
    if (enableTableBorder != null) await prefs.setBool(_keyEnableTableBorder, enableTableBorder);
    if (enableMinimalInfo != null) await prefs.setBool(_keyEnableMinimalInfo, enableMinimalInfo);
    if (showTimeOnReceipt != null) await prefs.setBool(_keyShowTimeOnReceipt, showTimeOnReceipt);
    if (showTaxIncludedPrice != null) await prefs.setBool(_keyShowTaxIncludedPrice, showTaxIncludedPrice);
    if (printFontSize != null) await prefs.setInt(_keyPrintFontSize, (printFontSize * 100).round());
    if (printLineHeight != null) await prefs.setInt(_keyPrintLineHeight, (printLineHeight * 100).round());
    if (invoiceIdPrefix != null) await prefs.setString(_keyInvoiceIdPrefix, invoiceIdPrefix);
    if (lastInvoiceId != null) await prefs.setInt(_keyLastInvoiceId, lastInvoiceId);
    if (lastOrderId != null) await prefs.setInt(_keyLastOrderId, lastOrderId);
    if (customTaxLabel != null) await prefs.setString(_keyCustomTaxLabel, customTaxLabel);
    if (customPayableLabel != null) await prefs.setString(_keyCustomPayableLabel, customPayableLabel);
    if (attachQrCode != null) await prefs.setBool(_keyAttachQrCode, attachQrCode);
    if (qrCodeData != null) await prefs.setString(_keyQrCodeData, qrCodeData);
    emit(state.copyWith(
      textOnlyPrint: textOnlyPrint,
      sortItemsAlphabetical: sortItemsAlphabetical,
      printCustomerInfo: printCustomerInfo,
      printSalesmanName: printSalesmanName,
      enablePaymentInfo: enablePaymentInfo,
      enableTableBorder: enableTableBorder,
      enableMinimalInfo: enableMinimalInfo,
      showTimeOnReceipt: showTimeOnReceipt,
      showTaxIncludedPrice: showTaxIncludedPrice,
      printFontSize: printFontSize,
      printLineHeight: printLineHeight,
      invoiceIdPrefix: invoiceIdPrefix,
      lastInvoiceId: lastInvoiceId,
      lastOrderId: lastOrderId,
      customTaxLabel: customTaxLabel,
      customPayableLabel: customPayableLabel,
      attachQrCode: attachQrCode,
      qrCodeData: qrCodeData,
    ));
  }

  Future<void> setReceiptTemplate(int template) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReceiptTemplate, template);
    emit(state.copyWith(receiptTemplate: template));
  }

  Future<void> setReceiptTitles({
    String? receiptTitle,
    String? receiptFooter,
    String? shopName,
    String? shopAddress,
    String? shopPhone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (receiptTitle != null) await prefs.setString(_keyReceiptTitle, receiptTitle);
    if (receiptFooter != null) await prefs.setString(_keyReceiptFooter, receiptFooter);
    if (shopName != null) await prefs.setString(_keyShopName, shopName);
    if (shopAddress != null) await prefs.setString(_keyShopAddress, shopAddress);
    if (shopPhone != null) await prefs.setString(_keyShopPhone, shopPhone);
    emit(state.copyWith(
      receiptTitle: receiptTitle,
      receiptFooter: receiptFooter,
      shopName: shopName,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
    ));
  }
}
