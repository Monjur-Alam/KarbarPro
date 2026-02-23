import 'package:flutter/material.dart';

/// Localization helper for the app. Returns strings for the current [locale] (bn or en).
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  bool get isBangla => locale.languageCode == 'bn';

  // ——— Drawer ———
  String get language => isBangla ? 'ভাষা' : 'Language';
  String get theme => isBangla ? 'থিম' : 'Theme';
  String get bangla => isBangla ? 'বাংলা' : 'Bangla';
  String get english => isBangla ? 'ইংরেজি' : 'English';
  String get light => isBangla ? 'লাইট' : 'Light';
  String get dark => isBangla ? 'ডার্ক' : 'Dark';
  String get systemDefault => isBangla ? 'সিস্টেম ডিফল্ট' : 'System Default';
  String get profile => isBangla ? 'প্রোফাইল' : 'Profile';
  String get settings => isBangla ? 'সেটিংস' : 'Settings';
  String get reports => isBangla ? 'রিপোর্টসমূহ' : 'Reports';
  String get backupRestore => isBangla ? 'ব্যাকআপ ও পুনরুদ্ধার' : 'Backup & Restore';
  String get about => isBangla ? 'অ্যাপ সম্পর্কে' : 'About';
  String get logout => isBangla ? 'লগআউট' : 'Logout';
  String get user => isBangla ? 'ব্যবহারকারী' : 'User';
  String get logoutConfirmTitle => isBangla ? 'লগআউট' : 'Logout';
  String get logoutConfirmMessage =>
      isBangla ? 'আপনি কি নিশ্চিতভাবে লগআউট করতে চান?' : 'Are you sure you want to logout?';
  String get no => isBangla ? 'না' : 'No';
  String get yes => isBangla ? 'হ্যাঁ' : 'Yes';

  // ——— Filter periods (internal value is Bangla in code; this returns display label) ———
  String get periodDaily => isBangla ? 'দৈনিক' : 'Daily';
  String get periodMonthly => isBangla ? 'মাসিক' : 'Monthly';
  String get periodYearly => isBangla ? 'বাৎসরিক' : 'Yearly';
  String get periodRange => isBangla ? 'পরিসর' : 'Range';

  /// Returns localized label for period value (Bangla key used in state).
  String getPeriodLabel(String periodValue) {
    switch (periodValue) {
      case 'দৈনিক':
        return periodDaily;
      case 'মাসিক':
        return periodMonthly;
      case 'বাৎসরিক':
        return periodYearly;
      case 'পরিসর':
        return periodRange;
      default:
        return periodValue;
    }
  }

  // ——— Dashboard ———
  String get appTitle => isBangla ? 'আমার দোকান' : 'My Shop';
  String get salesTitle => isBangla ? 'পণ্য বিক্রয়' : 'Sales';
  String get dueLedgerTitle => isBangla ? 'বাকি খাতা' : 'Due Ledger';
  String get inventoryTitle => isBangla ? 'পণ্যের তালিকা' : 'Inventory';
  String get expenseTitle => isBangla ? 'দোকানের খরচ' : 'Expenses';
  String get navHome => isBangla ? 'হোম' : 'Home';
  String get navSales => isBangla ? 'বিক্রয়' : 'Sales';
  String get navDueLedger => isBangla ? 'বাকি খাতা' : 'Due Ledger';
  String get navList => isBangla ? 'তালিকা' : 'List';
  String get navExpense => isBangla ? 'খরচ' : 'Expense';
  String get syncSyncing => isBangla ? 'সিঙ্ক হচ্ছে...' : 'Syncing...';
  String get syncOnline => isBangla ? 'অনলাইন' : 'Online';
  String get syncFailed => isBangla ? 'ব্যর্থ' : 'Failed';
  String get syncOffline => isBangla ? 'অফলাইন' : 'Offline';
  String get syncUsable => isBangla ? 'ব্যবহার্য' : 'Usable';
  String get sectionRecentSales => isBangla ? 'সাম্প্রতিক বিক্রি' : 'Recent Sales';
  String get sectionLowStock => isBangla ? 'সতর্কতা (স্টক কম)' : 'Low Stock Alert';
  String get errorPrefix => isBangla ? 'ত্রুটি: ' : 'Error: ';
  String get live => isBangla ? 'লাইভ' : 'Live';
  String get shopMainBalance => isBangla ? 'দোকানের মেইন ব্যালেন্স' : 'Shop Main Balance';
  String get totalSalesToday => isBangla ? 'মোট বিক্রি (আজ)' : 'Total Sales (Today)';
  String get totalAmountToday => isBangla ? 'মোট টাকা (আজ)' : 'Total Amount (Today)';
  String get profitToday => isBangla ? 'লাভ (আজ)' : 'Profit (Today)';
  String get reportSection => isBangla ? 'রিপোর্ট' : 'Reports';
  String get salesReport => isBangla ? 'বিক্রয় রিপোর্ট' : 'Sales Report';
  String get expenseReport => isBangla ? 'খরচ রিপোর্ট' : 'Expense Report';
  String get stockReport => isBangla ? 'স্টক রিপোর্ট' : 'Stock Report';
  String get dueLedgerReport => isBangla ? 'বাকি খাতা রিপোর্ট' : 'Due Ledger Report';
  String get dueSummaryTitle => isBangla ? 'বাকির খাতা সারসংক্ষেপ' : 'Due Ledger Summary';
  String get details => isBangla ? 'বিস্তারিত' : 'Details';
  String get iWillReceive => isBangla ? 'আমি পাবো' : 'I will receive';
  String get totalDue => isBangla ? 'মোট বাকি:' : 'Total due:';
  String get collected => isBangla ? 'আদায়:' : 'Collected:';
  String get remainingDue => isBangla ? 'বাকি আছে:' : 'Remaining:';
  String get iWillPay => isBangla ? 'আমি দিবো' : 'I will pay';
  String get paid => isBangla ? 'দিয়েছি:' : 'Paid:';
  String get remainingToPay => isBangla ? 'বাকি দিতে হবে:' : 'Remaining to pay:';
  String get noRecentSales => isBangla ? 'কোন সাম্প্রতিক বিক্রি নেই' : 'No recent sales';
  String get invoiceLabel => isBangla ? 'ইনভয়েস' : 'Invoice';
  String get stockLabel => isBangla ? 'স্টক' : 'Stock';

  // ——— Login ———
  String get appName => 'Amar Dokan';
  String get loginSubtitle => isBangla ? 'দোকান সফলভাবে পরিচালনা করুন' : 'Manage your shop efficiently';
  String get signInWithGoogle => isBangla ? 'গুগল দিয়ে সাইন ইন' : 'Sign in with Google';

  // ——— Profile ———
  String get autoBackup => isBangla ? 'অটো ব্যাকআপ' : 'Auto Backup';
  String get autoBackupSubtitle => isBangla ? 'সর্বদা গুগল ড্রাইভে সিঙ্ক থাকে' : 'Always synced to Google Drive';
  String get logOut => isBangla ? 'লগ আউট' : 'Log Out';

  // ——— Sales ———
  String get all => isBangla ? 'সব' : 'All';
  String get newSale => isBangla ? 'নতুন বিক্রি' : 'New Sale';
  String get retry => isBangla ? 'পুনরায় চেষ্টা করুন' : 'Retry';
  String get salesDataLoadError => isBangla ? 'বিক্রয় ডাটা লোড করা যাচ্ছে না' : 'Could not load sales data';
  String get totalSales => isBangla ? 'মোট বিক্রি' : 'Total Sales';
  String get creditSales => isBangla ? 'বাকি বিক্রি' : 'Credit Sales';
  String get report => isBangla ? 'রিপোর্ট' : 'Report';
  String get cash => isBangla ? 'নগদ' : 'Cash';
  String get credit => isBangla ? 'বাকি' : 'Credit';
  String get noSalesData => isBangla ? 'কোনো বিক্রয় তথ্য পাওয়া যায়নি' : 'No sales data found';
  String get unknownProduct => isBangla ? 'অজানা পণ্য' : 'Unknown product';
  String get sortNewestFirst => isBangla ? 'সর্বশেষ থেকে পুরাতন' : 'Newest first';
  String get sortOldestFirst => isBangla ? 'পুরাতন থেকে সর্বশেষ' : 'Oldest first';
  String get payment => isBangla ? 'পেমেন্ট:' : 'Payment:';
  String get printReceipt => isBangla ? 'প্রিন্ট রসিদ' : 'Print Receipt';
  String get shareReceipt => isBangla ? 'রসিদ শেয়ার করুন' : 'Share Receipt';
  String get close => isBangla ? 'বন্ধ করুন' : 'Close';
  String get shopNameForReport => isBangla ? 'আমার দোকান' : 'My Shop';
  String get searchInvoiceOrCustomer => isBangla ? 'ইনভয়েস বা গ্রাহক খুঁজুন...' : 'Search invoice or customer...';
  String get saleSuccess => isBangla ? 'বিক্রয় সফল হয়েছে!' : 'Sale successful!';
  String get totalAmountLabel => isBangla ? 'মোট পরিমাণ:' : 'Total amount:';
  String get invoiceColon => isBangla ? 'ইনভয়েস:' : 'Invoice:';
  String get offlineSalesBanner => isBangla ? 'অফলাইন মোডে বিক্রয় - ডেটা পরবর্তীতে সিঙ্ক হবে' : 'Offline sales mode - data will sync later';
  String get sortBy => isBangla ? 'সাজান (Sort By)' : 'Sort By';
  String get sortAmountDesc => isBangla ? 'টাকার অঙ্ক (বেশি থেকে কম)' : 'Amount (high to low)';
  String get sortAmountAsc => isBangla ? 'টাকার অঙ্ক (কম থেকে বেশি)' : 'Amount (low to high)';
  String get totalPrefix => isBangla ? 'মোট' : 'Total';

  // ——— Inventory ———
  String get addNewItem => isBangla ? 'নতুন আইটেম যোগ' : 'Add New Item';
  String get searchProducts => isBangla ? 'পণ্য অনুসন্ধান করুন...' : 'Search products...';
  String get allStock => isBangla ? 'সমস্ত স্টক' : 'All Stock';
  String get inStock => isBangla ? 'স্টক আছে' : 'In Stock';
  String get lowStock => isBangla ? 'কম স্টক' : 'Low Stock';
  String get outOfStock => isBangla ? 'স্টক শেষ' : 'Out of Stock';
  String get allCategories => isBangla ? 'সব ক্যাটাগরি' : 'All Categories';
  String get manageCategories => isBangla ? 'ক্যাটাগরি ম্যানেজ করুন' : 'Manage Categories';
  String get sellingPrice => isBangla ? 'বিক্রয়' : 'Selling';
  String get purchasePrice => isBangla ? 'ক্রয়' : 'Purchase';
  String get quantity => isBangla ? 'পরিমাণ' : 'Qty';
  String get noProductsFound => isBangla ? 'কোনো পণ্য পাওয়া যায়নি' : 'No products found';
  String get addProductHint => isBangla ? 'নতুন পণ্য যোগ করতে নিচের বাটনে ক্লিক করুন' : 'Tap the button below to add a new product';
  String get sortLatest => isBangla ? 'সর্বশেষ' : 'Latest';
  String get camera => isBangla ? 'ক্যামেরা' : 'Camera';
  String get gallery => isBangla ? 'গ্যালারি' : 'Gallery';
  String get permissionRequired => isBangla ? 'অনুমতি প্রয়োজন' : 'Permission required';
  String get cancel => isBangla ? 'বাতিল' : 'Cancel';
  String get enterItemName => isBangla ? 'আইটেমের নাম লিখুন' : 'Enter item name';
  String get enterSellingPrice => isBangla ? 'বিক্রয় মূল্য লিখুন' : 'Enter selling price';
  String get addProductInstructionsTitle => isBangla ? 'পণ্য যোগ করার নির্দেশনা' : 'How to add a product';
  String get instruction1 => isBangla ? 'আইটেমের নাম লিখুন (বাধ্যতামূলক)' : 'Enter item name (required)';
  String get instruction2 => isBangla ? 'ক্যাটাগরি নির্বাচন করুন (ঐচ্ছিক)' : 'Select category (optional)';
  String get instruction3 => isBangla ? 'বিক্রয় মূল্য এবং ক্রয় মূল্য লিখুন' : 'Enter selling and purchase price';
  String get instruction4 => isBangla ? 'প্রাথমিক স্টক পরিমাণ এবং একক লিখুন' : 'Enter initial stock and unit';
  String get instruction5 => isBangla ? 'প্রয়োজনে আইটেম কোড এবং বিবরণ যোগ করুন' : 'Add item code and description if needed';
  String get instruction6 => isBangla ? 'ছবি যোগ করতে ক্যামেরা আইকনে ক্লিক করুন' : 'Tap camera icon to add image';
  String get instruction7 => isBangla ? 'সব তথ্য পূরণ করে "সেভ করুন" বাটনে ক্লিক করুন' : 'Fill all fields and tap Save';
  String get gotIt => isBangla ? 'বুঝেছি' : 'Got it';
  String get editItem => isBangla ? 'আইটেম সম্পাদনা' : 'Edit Item';
  String get itemNameHint => isBangla ? 'আইটেমের নাম লিখুন' : 'Enter item name';
  String get categoryLabel => isBangla ? 'শ্রেণী' : 'Category';
  String get selectCategory => isBangla ? 'ক্যাটাগরি নির্বাচন করুন' : 'Select category';
  String get addNewCategory => isBangla ? 'নতুন ক্যাটাগরি যোগ করুন' : 'Add New Category';
  String get newCategory => isBangla ? 'নতুন ক্যাটাগরি' : 'New Category';
  String get categoryHint => isBangla ? 'ক্যাটাগরি লিখুন' : 'Enter category';
  String get addLabel => isBangla ? 'যোগ করুন' : 'Add';
  String get initialStock => isBangla ? 'প্রাথমিক স্টক' : 'Initial Stock';
  String get unit => isBangla ? 'একক' : 'Unit';
  String get itemCode => isBangla ? 'আইটেম কোড' : 'Item Code';
  String get itemCodeHint => isBangla ? 'আইটেম কোড লিখুন' : 'Enter item code';
  String get description => isBangla ? 'বিবরণ' : 'Description';
  String get descriptionHint => isBangla ? 'বিবরণ লিখুন' : 'Enter description';
  String get addItemImage => isBangla ? 'আইটেমের ছবি যোগ করুন' : 'Add item image';
  String get save => isBangla ? 'সেভ করুন' : 'Save';

  // ——— Due Ledger & Expense (shared) ———
  String get filterAll => isBangla ? 'সব' : 'All';
  String get addNew => isBangla ? 'নতুন যোগ' : 'Add New';
  String get income => isBangla ? 'জমা' : 'Income';
  String get expenseLabel => isBangla ? 'খরচ' : 'Expense';
  String get totalReceive => isBangla ? 'মোট পাবো' : 'Total to receive';
  String get totalPay => isBangla ? 'মোট দিবো' : 'Total to pay';
  String get collectedLabel => isBangla ? 'আদায় হয়েছে' : 'Collected';
  String get paidLabel => isBangla ? 'দিয়েছি' : 'Paid';
  String get customer => isBangla ? 'গ্রাহক' : 'Customer';
  String get supplier => isBangla ? 'সরবরাহকারী' : 'Supplier';
  String get sortByLastTransaction => isBangla ? 'সর্বশেষ লেনদেন' : 'Last transaction';
  String get noPhone => isBangla ? 'ফোন নম্বর নেই' : 'No phone';
  String get cannotDeleteCustomerWithDue => isBangla ? 'বাকি পরিশোধ না করে গ্রাহক মুছা যাবে না' : 'Cannot delete customer with due balance';
  String get delete => isBangla ? 'মুছুন' : 'Delete';
  String get customerDeleted => isBangla ? 'গ্রাহক মুছে ফেলা হয়েছে' : 'Customer deleted';
  String get warning => isBangla ? 'সতর্কতা' : 'Warning';
  String get deleteConfirm => isBangla ? 'মুছে ফেলুন' : 'Delete';
  String get editCustomerInfo => isBangla ? 'গ্রাহক তথ্য পরিবর্তন করুন' : 'Edit customer info';
  String get recordPayment => isBangla ? 'বকেয়া পরিশোধের হিসাব রাখুন' : 'Record payment';
  String get recordPaymentSubtitle => isBangla ? 'কাস্টমারের কাছ থেকে টাকা জমা নিন' : 'Collect payment from customer';
  String get transactionHistory => isBangla ? 'বাকি লেনদেনের ইতিহাস' : 'Transaction history';
  String get contact => isBangla ? 'যোগাযোগ করুন' : 'Contact';
  String get editCustomer => isBangla ? 'গ্রাহক সম্পাদনা' : 'Edit customer';
  String get customerUpdated => isBangla ? 'গ্রাহক তথ্য আপডেট হয়েছে' : 'Customer updated';
  String get noCustomersFound => isBangla ? 'কোনো গ্রাহক পাওয়া যায়নি' : 'No customers found';
  String get totalIncome => isBangla ? 'মোট জমা:' : 'Total income:';
  String get totalExpense => isBangla ? 'মোট খরচ:' : 'Total expense:';
  String get balance => isBangla ? 'ব্যালেন্স:' : 'Balance:';

  /// Format number for display (Bengali digits when locale is bn).
  String formatAmount(num value) {
    final s = value.toStringAsFixed(0);
    if (!isBangla) return s;
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    return s.split('').map((c) => en.contains(c) ? bn[en.indexOf(c)] : c).join();
  }

  /// Format any string of digits by locale (e.g. invoice id, count).
  String formatDigits(String input) {
    if (!isBangla) return input;
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    return input.split('').map((c) => en.contains(c) ? bn[en.indexOf(c)] : c).join('');
  }
}

extension AppLocalizationsExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations(Localizations.localeOf(this));
}
