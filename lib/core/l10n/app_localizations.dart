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
  String get resetData => isBangla ? 'ডাটা রিসেট' : 'Reset Data';
  String get resetDataConfirmTitle => isBangla ? 'ডাটা রিসেট করুন' : 'Reset Data';
  String get resetDataConfirmMessage => isBangla
      ? 'এটি আপনার সমস্ত ডাটা (বিক্রয়, পণ্য, গ্রাহক, খরচ) এবং গুগল ড্রাইভের সকল ব্যাকআপ স্থায়ীভাবে মুছে ফেলবে। এই কাজটি পূর্বাবস্থায় ফেরানো যাবে না!'
      : 'This will permanently delete all your data (sales, products, customers, expenses) and all Google Drive backups. This action cannot be undone!';
  String get resetDataSuccess => isBangla ? 'সমস্ত ডাটা সফলভাবে রিসেট করা হয়েছে' : 'All data has been reset successfully';
  String get resetDataButton => isBangla ? 'রিসেট করুন' : 'Reset';

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
  String get appName => isBangla ? 'কারবার প্রো' : 'Karbar Pro';
  String get loginSubtitle => isBangla ? 'আপনার ব্যবসা, এক অ্যাপেই' : 'Your business, all in one app';
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
  String get itemCode => isBangla ? 'আইটেম কোড (বারকোড)' : 'Item Code (Barcode)';
  String get itemCodeHint => isBangla ? 'স্বয়ংক্রিয়ভাবে তৈরি হবে' : 'Auto-generated';
  String get productSize => isBangla ? 'সাইজ' : 'Size';
  String get sizeHint => isBangla ? 'সাইজ লিখুন (যেমন: S, M, L, ৩৮)' : 'Enter size (e.g., S, M, L, 38)';
  String get printBarcode => isBangla ? 'বারকোড প্রিন্ট' : 'Print Barcode';
  String get barcodePreview => isBangla ? 'বারকোড প্রিভিউ' : 'Barcode Preview';
  String get description => isBangla ? 'বিবরণ' : 'Description';
  String get descriptionHint => isBangla ? 'বিবরণ লিখুন' : 'Enter description';
  String get addItemImage => isBangla ? 'আইটেমের ছবি যোগ করুন' : 'Add item image';
  String get save => isBangla ? 'সেভ করুন' : 'Save';

  // ——— Sale Form Bottom Sheet ———
  String get newSaleInvoice => isBangla ? 'নতুন বিক্রয় (ইনভয়েস)' : 'New Sale (Invoice)';
  String get selectProduct => isBangla ? 'পণ্য নির্বাচন করুন' : 'Select Product';
  String get selectProductHint => isBangla ? 'পণ্য নির্বাচন করুন...' : 'Select a product...';
  String get quantityRequired => isBangla ? 'পরিমাণ *' : 'Quantity *';
  String get unitPriceRequired => isBangla ? 'মূল্য (একক) *' : 'Unit Price *';
  String get addToCart => isBangla ? 'কার্টে যোগ করুন' : 'Add to Cart';
  String get paymentInfo => isBangla ? 'পেমেন্ট তথ্য' : 'Payment Info';
  String get cashPayment => isBangla ? 'নগদ (Cash)' : 'Cash';
  String get creditPayment => isBangla ? 'বাকি (Credit)' : 'Credit';
  String get selectCustomer => isBangla ? 'গ্রাহক নির্বাচন করুন' : 'Select Customer';
  String get selectCustomerHint => isBangla ? 'গ্রাহক নির্বাচন করুন...' : 'Select a customer...';
  String get cashCollectedQuestion => isBangla ? 'নগদ আদায় হয়েছে?' : 'Cash collected?';
  String get collectedAmount => isBangla ? 'আদায়ের পরিমাণ' : 'Collected Amount';
  String get discount => isBangla ? 'ডিসকাউন্ট' : 'Discount';
  String get discountTaka => isBangla ? 'ডিসকাউন্ট (টাকা)' : 'Discount (Tk)';
  String get additionalNotes => isBangla ? 'অতিরিক্ত নোট (ঐচ্ছিক)' : 'Additional Notes (Optional)';
  String get subTotal => isBangla ? 'উপ-মোট:' : 'Sub-total:';
  String get grandTotal => isBangla ? 'সর্বমোট দেয়:' : 'Grand Total:';
  String get collectedColon => isBangla ? 'আদায়কৃত:' : 'Collected:';
  String get dueRemaining => isBangla ? 'বাকি থাকবে:' : 'Due Remaining:';
  String get completeSale => isBangla ? 'বিক্রয় সম্পন্ন করুন' : 'Complete Sale';
  String get selectCustomerWarning => isBangla ? 'গ্রাহক নির্বাচন করুন!' : 'Please select a customer!';
  String get addNewCustomer => isBangla ? 'নতুন গ্রাহক যোগ করুন' : 'Add New Customer';
  String get nameRequired => isBangla ? 'নাম *' : 'Name *';
  String get phoneRequired => isBangla ? 'ফোন নম্বর *' : 'Phone *';
  String get searchCustomer => isBangla ? 'গ্রাহক খুঁজুন...' : 'Search customer...';
  String get searchProduct => isBangla ? 'পণ্য খুঁজুন...' : 'Search product...';
  String get noDataFound => isBangla ? 'কোনো তথ্য পাওয়া যায়নি' : 'No data found';
  String get scanBarcode => isBangla ? 'বারকোড স্ক্যান করুন' : 'Scan barcode';
  String get productNotFound => isBangla ? 'পণ্য পাওয়া যায়নি' : 'Product not found';
  String get cameraPermissionRequired => isBangla ? 'ক্যামেরার অনুমতি প্রয়োজন' : 'Camera permission required';
  String get grantPermission => isBangla ? 'অনুমতি দিন' : 'Grant Permission';
  String cartListCount(String count) => isBangla ? 'কার্ট তালিকা (${count}টি)' : 'Cart ($count items)';
  String stockInfo(String stock, String unit) => isBangla ? 'স্টক: $stock $unit' : 'Stock: $stock $unit';

  // ——— Inventory Sort ———
  String get sortLabel => isBangla ? 'সাজান:' : 'Sort by:';
  String get sortQuantityHighToLow => isBangla ? 'পরিমাণ (বেশি থেকে কম)' : 'Quantity (high to low)';
  String get sortQuantityLowToHigh => isBangla ? 'পরিমাণ (কম থেকে বেশি)' : 'Quantity (low to high)';
  String get sortNameAZ => isBangla ? 'নাম (A-Z)' : 'Name (A-Z)';
  String get sortNameZA => isBangla ? 'নাম (Z-A)' : 'Name (Z-A)';

  // ——— Product Form Bottom Sheet ———
  String get noCategoriesHint => isBangla ? 'কোনো ক্যাটাগরি নেই। নতুন ক্যাটাগরি লিখুন।' : 'No categories yet. Enter a new one.';
  String get cameraPermissionMessage => isBangla ? 'ছবি তুলতে ক্যামেরা অনুমতি প্রয়োজন। সেটিংস থেকে অনুমতি দিন।' : 'Camera permission is required. Please grant it from settings.';
  String get openSettings => isBangla ? 'সেটিংস খুলুন' : 'Open Settings';
  String get sellingPriceRequired => isBangla ? 'বিক্রয় মূল্য *' : 'Selling Price *';
  String get purchasePriceLabel => isBangla ? 'ক্রয় মূল্য' : 'Purchase Price';
  String get itemNameRequired => isBangla ? 'আইটেমের নাম *' : 'Item Name *';

  // ——— Due Ledger & Expense (shared) ———
  String get filterAll => isBangla ? 'সব' : 'All';
  String get addNew => isBangla ? 'নতুন যোগ' : 'Add New';
  String get income => isBangla ? 'জমা' : 'Income';
  String get expenseLabel => isBangla ? 'ব্যয়' : 'Expense';
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
  String get newSupplier => isBangla ? 'নতুন সরবরাহকারী' : 'New Supplier';
  String get newCustomer => isBangla ? 'নতুন গ্রাহক' : 'New Customer';
  String get type => isBangla ? 'ধরণ' : 'Type';
  String get customerReceivable => isBangla ? 'গ্রাহক (আমি পাবো)' : 'Customer (I will receive)';
  String get supplierPayable => isBangla ? 'সাপ্লায়ার (আমি দিবো)' : 'Supplier (I will pay)';
  String get nameRequiredLabel => isBangla ? 'নাম (আবশ্যক)' : 'Name (Required)';
  String get phoneRequiredLabel => isBangla ? 'ফোন নম্বর (আবশ্যক)' : 'Phone Number (Required)';
  String get addressOptional => isBangla ? 'ঠিকানা (ঐচ্ছিক)' : 'Address (Optional)';
  String get commentOptional => isBangla ? 'মন্তব্য (ঐচ্ছিক)' : 'Comment (Optional)';
  String get namePhoneRequiredError => isBangla ? 'নাম এবং ফোন নম্বর প্রয়োজন' : 'Name and phone number are required';
  String get customerAdded => isBangla ? 'গ্রাহক যুক্ত হয়েছে' : 'Customer added';
  String get collectMoney => isBangla ? 'টাকা জমা নিন' : 'Collect Money';
  String get currentDue => isBangla ? 'বর্তমান বাকি' : 'Current Due';
  String get amountToCollect => isBangla ? 'জমা করা টাকার পরিমাণ' : 'Amount to Collect';
  String get noteOptional => isBangla ? 'নোট (ঐচ্ছিক)' : 'Note (Optional)';
  String get enterCorrectAmount => isBangla ? 'সঠিক পরিমাণ লিখুন' : 'Enter correct amount';
  String get moneyCollectionSuccess => isBangla ? 'টাকা জমা নেওয়া সফল হয়েছে' : 'Money collection successful';
  String get confirm => isBangla ? 'নিশ্চিত করুন' : 'Confirm';
  String get noTransactionHistory => isBangla ? 'কোনো লেনদেনের ইতিহাস নেই' : 'No transaction history';
  String get productPurchaseDue => isBangla ? 'পণ্য ক্রয় (বাকি)' : 'Product Purchase (Due)';
  String get payMoney => isBangla ? 'টাকা পরিশোধ' : 'Pay Money';
  String get call => isBangla ? 'কল করুন' : 'Call';
  String get sendSms => isBangla ? 'এসএমএস পাঠান' : 'Send SMS';
  String get yourShopDueMessage => isBangla ? 'আপনার দোকানের বাকি' : 'Your shop due';
  String get paymentRequestMessage => isBangla ? 'পরিশোধ করার জন্য অনুরোধ করা হলো।' : 'Payment request initiated.';
  String get deleteCustomerConfirm => isBangla ? 'আপনি কি এই গ্রাহককে মুছে ফেলতে চান?' : 'Are you sure you want to delete this customer?';
  String get name => isBangla ? 'নাম' : 'Name';
  String get due => isBangla ? 'বাকি' : 'Due';
  String get date => isBangla ? 'তারিখ' : 'Date';
  String get amountLabel => isBangla ? 'পরিমাণ' : 'Amount';
  String get allTransactionsDeletedWarning => isBangla ? 'সকল লেনদেন ইতিহাস মুছে যাবে!' : 'All transaction history will be deleted!';
  String get sortDueHighToLow => isBangla ? 'বাকি (বেশি থেকে কম)' : 'Due (high to low)';
  String get sortDueLowToHigh => isBangla ? 'বাকি (কম থেকে বেশি)' : 'Due (low to high)';
  String get editTransaction => isBangla ? 'লেনদেন সম্পাদনা' : 'Edit Transaction';
  String get depositJoma => isBangla ? 'টাকা জমা (Joma)' : 'Deposit (Joma)';
  String get expenseKhoroch => isBangla ? 'খরচ (Khoroch)' : 'Expense (Khoroch)';
  String get categoryOrSource => isBangla ? 'খাত বা উৎস' : 'Category or Source';
  String get selectCategoryHint => isBangla ? 'খাত নির্বাচন করুন' : 'Select Category';
  String get addNewCategoryAction => isBangla ? '+ নতুন খাত যোগ করুন' : '+ Add New Category';
  String get amountTaka => isBangla ? 'টাকার পরিমাণ' : 'Amount (Taka)';
  String get descriptionOptional => isBangla ? 'বিবরণ (ঐচ্ছিক)' : 'Description (Optional)';
  String get transactionUpdated => isBangla ? 'লেনদেন আপডেট করা হয়েছে' : 'Transaction updated';
  String get transactionUpdateFailed => isBangla ? 'আপডেট করতে সমস্যা হয়েছে' : 'Transaction update failed';
  String get deleteTransactionConfirmQuestion => isBangla ? 'আপনি কি এই লেনদেনটি মুছে ফেলতে চান?' : 'Are you sure you want to delete this transaction?';
  String get transactionDeleted => isBangla ? 'লেনদেন মুছে ফেলা হয়েছে' : 'Transaction deleted';
  String get transactionDeleteFailed => isBangla ? 'মুছে ফেলতে সমস্যা হয়েছে' : 'Transaction delete failed';
  String get addNewCategoryTitle => isBangla ? 'নতুন খাত যোগ করুন' : 'Add New Category';
  String get categoryNameLabel => isBangla ? 'খাতের নাম' : 'Category Name';
  String get categoryNameHint => isBangla ? 'উদা: যাতায়াত' : 'e.g. Transport';
  String get categoryAlreadyExistsError => isBangla ? 'এই নামে ইতিমধ্যে একটি খাত আছে' : 'A category with this name already exists';
  String get depositMoneyTitle => isBangla ? 'টাকা জমা দিন' : 'Deposit Money';
  String get recordExpenseTitle => isBangla ? 'খরচ রেকর্ড করুন' : 'Record Expense';
  String get depositSourceLabel => isBangla ? 'জমার উৎস' : 'Deposit Source';
  String get expenseCategoryLabel => isBangla ? 'খরচের খাত' : 'Expense Category';
  String get amountRequired => isBangla ? 'পরিমাণ আবশ্যক' : 'Amount Required';
  String get searchExpense => isBangla ? 'খুঁজুন...' : 'Search...';
  String get depositSuccess => isBangla ? 'সাফল্যের সাথে যোগ করা হয়েছে' : 'Deposit added successfully';
  String get expenseRecorded => isBangla ? 'খরচ রেকর্ড করা হয়েছে' : 'Expense recorded successfully';
  String get noResultsFound => isBangla ? 'কোনো ফলাফল পাওয়া যায়নি' : 'No results found';
  String get noTransactionsRecorded => isBangla ? 'কোনো লেনদেন রেকর্ড করা হয়নি' : 'No transactions recorded';
  String get amountColon => isBangla ? 'পরিমাণ:' : 'Amount:';
  String get categoryColon => isBangla ? 'খাত:' : 'Category:';
  String get deleteConfirmAction => isBangla ? 'মুছে ফেলুন' : 'Delete';
  String get selectMonthTitle => isBangla ? 'মাস নির্বাচন করুন' : 'Select Month';
  String get showCurrentMonth => isBangla ? 'বর্তমান মাস দেখুন' : 'Show Current Month';
  String get goodMorning => isBangla ? 'শুভ সকাল' : 'Good Morning';
  String get goodAfternoon => isBangla ? 'শুভ দুপুর' : 'Good Afternoon';
  String get goodEvening => isBangla ? 'শুভ সন্ধ্যা' : 'Good Evening';
  String get goodNight => isBangla ? 'শুভ রাত্রি' : 'Good Night';
  String get incomeLabel => isBangla ? 'আয়' : 'Income';
  String get totalBalanceLabel => isBangla ? 'মোট ব্যালেন্স' : 'Total Balance';
  String get totalPeriodLabel => isBangla ? 'মোট' : 'Total';
  String get cashInHand => isBangla ? 'হাতে নগদ' : 'Cash In hand';
  String get cashIn => isBangla ? 'ক্যাশ ইন' : 'Cash In';
  String get cashOut => isBangla ? 'ক্যাশ আউট' : 'Cash Out';
  String get totalSalesCash => isBangla ? 'নগদ বিক্রি' : 'Total Sales in Cash';
  String get totalSalesCredit => isBangla ? 'বাকি বিক্রি' : 'Total Sales in Credit';
  String get paidToSupplierLabel => isBangla ? 'সাপ্লায়ারকে পরিশোধ' : 'Paid to Supplier';
  String get dueCollectionLabel => isBangla ? 'বাকি আদায়' : 'Due Collection';
  String get totalReceivableLabel => isBangla ? 'মোট পাওনা' : 'Total Receivable';
  String get totalPayableLabel => isBangla ? 'মোট দেনা' : 'Total Payable';

  // ——— Receipt Settings ———
  String get receiptSettings => isBangla ? 'রসিদ সেটিংস' : 'Receipt Settings';
  String get enableTextOnlyPrint => isBangla ? 'টেক্সট অনলি প্রিন্ট চালু করুন' : 'Enable text only print';
  String get textOnlyPrintDesc => isBangla ? 'টেক্সট অনলি প্রিন্ট মোড শুধু ইংরেজি ভাষায় প্রিন্ট করতে পারে\nতবে প্রিন্টিং দ্রুত হবে এবং বেশিরভাগ প্রিন্টারে সাপোর্ট করবে' : 'Text only print mode can print only english language\nbut printing will fast, support most type of printers';
  String get basicTab => isBangla ? 'বেসিক' : 'Basic';
  String get templatesTab => isBangla ? 'টেম্পলেটস' : 'Templates';
  String get receiptTitlesTab => isBangla ? 'রসিদ শিরোনাম' : 'Receipt Titles';
  String get sortItemsAlphabetical => isBangla ? 'রসিদে আইটেমগুলো বর্ণানুক্রমিক সাজান' : 'Sort items alphabetical in receipt';
  String get printCustomerInfoSetting => isBangla ? 'রসিদে গ্রাহকের তথ্য প্রিন্ট করুন' : 'Print customer info in receipt';
  String get printSalesmanName => isBangla ? 'বিলে সেলস ম্যানের নাম প্রিন্ট করুন' : 'Print sales man name in bill';
  String get enablePaymentInfoSetting => isBangla ? 'বিলে পেমেন্ট তথ্য চালু করুন' : 'Enable payment info in bill';
  String get enableTableBorder => isBangla ? 'টেবিলের বর্ডার চালু করুন' : 'Enable table border';
  String get enableMinimalInfo => isBangla ? 'বিলে সংক্ষিপ্ত তথ্য চালু করুন' : 'Enable minimal info in bill';
  String get showTimeOnReceipt => isBangla ? 'রসিদে সময় দেখান' : 'Show time on receipt';
  String get showTaxIncludedPrice => isBangla ? 'রসিদ লাইনে ট্যাক্স সহ মূল্য দেখান' : 'Show tax included price in receipt lines';
  String get printFontSize => isBangla ? 'প্রিন্ট ফন্ট সাইজ' : 'Print font size';
  String get printLineHeight => isBangla ? 'প্রিন্ট লাইন হাইট' : 'Print line height';
  String get invoiceIdPrefixLbl => isBangla ? 'ইনভয়েস আইডি প্রিফিক্স' : 'INVOICE ID PREFIX';
  String get lastInvoiceIdLbl => isBangla ? 'সর্বশেষ ইনভয়েস আইডি' : 'LAST INVOICE ID';
  String get lastOrderIdLbl => isBangla ? 'সর্বশেষ অর্ডার আইডি' : 'LAST ORDER ID';
  String get customLabelForTaxLbl => isBangla ? 'ট্যাক্সের জন্য কাস্টম লেবেল' : 'CUSTOM LABEL FOR TAX';
  String get customNameForPayableLbl => isBangla ? 'পরিশোধযোগ্য হিসেবে কাস্টম নাম' : 'CUSTOM NAME FOR PAYABLE';
  String get attachQrCodeLbl => isBangla ? 'কিউআর কোড যুক্ত করুন' : 'Attach Qr Code';
  String get enterQrCodeDataLbl => isBangla ? 'কিউআর কোড ডেটা লিখুন' : 'Enter QR code data';
  String get newLineInstructionLbl => isBangla ? 'রসিদে নতুন লাইনের জন্য শব্দের মাঝে </br> ব্যবহার করুন' : 'Use </br> in between words for new line in receipt';
  String get taxInstructionLbl => isBangla ? 'রসিদে প্রিন্ট করার জন্য আপনি ট্যাক্সের কাস্টম নাম সেট করতে পারেন\nযেমন ভ্যাট(৫%), জিএসটি(১৮%) ..ইত্যাদি' : 'You can set custom name for Tax that print in receipt\neg VAT(5%), GST(18%) ..etc';
  String get selectedTemplate => isBangla ? 'নির্বাচিত' : 'Selected';
  String get selectThisTemplateBtn => isBangla ? 'এই টেমপ্লেটটি নির্বাচন করুন' : 'Select This Template';
  String get okayBtn => isBangla ? 'ওকে' : 'Okay';
  String get tplDetailedPos => isBangla ? 'বিস্তারিত পস' : 'Detailed POS';
  String get tplStandard => isBangla ? 'স্ট্যান্ডার্ড' : 'Standard';
  String get tplBigFont => isBangla ? 'বড় ফন্ট' : 'Big Font';
  String get tplQrCode => isBangla ? 'কিউআর কোড' : 'QR Code';
  String get tplBarcode => isBangla ? 'বারকোড' : 'Barcode';
  String get tplTicket => isBangla ? 'টিকেট' : 'Ticket';
  String get tplA4Style1 => isBangla ? 'এ৪-স্টাইল ১' : 'A4-Style 1';
  String get shopNameLbl => isBangla ? 'দোকানের নাম' : 'SHOP NAME';
  String get shopAddressLbl => isBangla ? 'দোকানের ঠিকানা' : 'SHOP ADDRESS';
  String get shopPhoneLbl => isBangla ? 'দোকানের ফোন' : 'SHOP PHONE';
  String get receiptTitleLbl => isBangla ? 'রসিদের শিরোনাম' : 'RECEIPT TITLE';
  String get footerTextLbl => isBangla ? 'ফুটার টেক্সট' : 'FOOTER TEXT';
  String get shopNameHint => isBangla ? 'আমার দোকান' : 'My Shop';
  String get shopAddressHint => isBangla ? 'দোকানের ঠিকানা' : 'Shop Address';
  String get shopPhoneHint => isBangla ? '০১XXXXXXXXX' : '01XXXXXXXXX';
  String get receiptTitleHint => isBangla ? 'বিক্রয় চালান' : 'Sales Invoice';
  String get footerTextHint => isBangla ? 'ধন্যবাদ আবার আসবেন' : 'Thank you, come again';

  // ── Template preview labels ─────────────────────────────────────────────
  String get previewSalesInvoice => isBangla ? 'বিক্রয় চালান' : 'Sales Invoice';
  String get previewInvoiceNo => isBangla ? 'চালান নং:' : 'Invoice No:';
  String get previewDate => isBangla ? 'তারিখ:' : 'Date:';
  String get previewPaymentMethod => isBangla ? 'পেমেন্ট পদ্ধতি' : 'Payment Method';
  String get previewCash => isBangla ? 'নগদ' : 'Cash';
  String get previewPriceAmount => isBangla ? 'মূল্য পরিমাণ' : 'Price Amount';
  String get previewBillAmount => isBangla ? 'বিলের পরিমাণ' : 'Bill Amount';
  String get previewPaid => isBangla ? 'পরিশোধিত' : 'Paid';
  String get previewSubTotal => isBangla ? 'উপ-মোট' : 'Sub Total';
  String get previewGrandTotal => isBangla ? 'সর্বমোট' : 'Grand Total';
  String get previewPayable => isBangla ? 'পরিশোধযোগ্য' : 'Payable';
  String get previewItemDesc => isBangla ? 'পণ্যের বিবরণ' : 'Item Description';
  String get previewItem => isBangla ? 'আইটেম' : 'Item';
  String get previewPrice => isBangla ? 'মূল্য' : 'Price';
  String get previewDisc => isBangla ? 'ছাড়' : 'Disc';
  String get previewAmt => isBangla ? 'পরিমাণ' : 'Amt';
  String get previewQty => isBangla ? 'পরিমাণ' : 'Qty';
  String get previewTotal => isBangla ? 'মোট' : 'Total';
  String get previewInvoiceDetails => isBangla ? 'চালানের বিবরণ' : 'Invoice Details';
  String get previewOrderId => isBangla ? 'অর্ডার আইডি:' : 'Order ID:';
  String get previewPaymentInfo => isBangla ? 'পেমেন্ট তথ্য' : 'Payment Information';
  String get previewTicket => isBangla ? 'টিকেট:' : 'Ticket:';
  String get previewBdt => isBangla ? 'টাকা' : 'BDT';
  String get previewPayment => isBangla ? 'পেমেন্ট:' : 'Payment:';
  String get previewDue => isBangla ? 'বাকি' : 'Due';

  /// Format number for display (Bengali digits when locale is bn).
  String formatAmount(num value) {
    final s = value.toStringAsFixed(0);
    if (!isBangla) return s;
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    return s.split('').map((c) => en.contains(c) ? bn[en.indexOf(c)] : c).join();
  }

  // Action chip short labels
  String get actionEdit => isBangla ? 'সম্পাদনা' : 'Edit';
  String get actionPayment => isBangla ? 'পেমেন্ট' : 'Payment';
  String get actionHistory => isBangla ? 'ইতিহাস' : 'History';
  String get actionSms => 'SMS';
  String get actionWhatsApp => 'WhatsApp';
  String get actionCall => isBangla ? 'কল' : 'Call';

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
