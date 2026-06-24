import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';

const _kNavy = AppColors.primary;

class ReceiptSettingsScreen extends StatefulWidget {
  const ReceiptSettingsScreen({super.key});

  @override
  State<ReceiptSettingsScreen> createState() => _ReceiptSettingsScreenState();
}

class _ReceiptSettingsScreenState extends State<ReceiptSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // Top toggle
  late bool _textOnlyPrint;

  // Basic toggles
  late bool _sortItemsAlphabetical;
  late bool _printCustomerInfo;
  late bool _printSalesmanName;
  late bool _enablePaymentInfo;
  late bool _enableTableBorder;
  late bool _enableMinimalInfo;
  late bool _showTimeOnReceipt;
  late bool _showTaxIncludedPrice;

  // Sliders
  late double _printFontSize;
  late double _printLineHeight;

  // Input field controllers
  late TextEditingController _invoicePrefixCtrl;
  late TextEditingController _lastInvoiceIdCtrl;
  late TextEditingController _lastOrderIdCtrl;
  late TextEditingController _taxLabelCtrl;
  late TextEditingController _payableLabelCtrl;

  // QR
  late bool _attachQrCode;
  late TextEditingController _qrDataCtrl;

  // Template
  late int _receiptTemplate;

  // Receipt titles
  late TextEditingController _receiptTitleCtrl;
  late TextEditingController _receiptFooterCtrl;
  late TextEditingController _shopNameCtrl;
  late TextEditingController _shopAddressCtrl;
  late TextEditingController _shopPhoneCtrl;

  // Dynamic surface color — adapts to dark mode
  Color get _surface => Theme.of(context).colorScheme.surface;
  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _outline => Theme.of(context).colorScheme.outline.withOpacity(0.2);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    final s = context.read<AppSettingsCubit>().state;
    _textOnlyPrint = s.textOnlyPrint;
    _sortItemsAlphabetical = s.sortItemsAlphabetical;
    _printCustomerInfo = s.printCustomerInfo;
    _printSalesmanName = s.printSalesmanName;
    _enablePaymentInfo = s.enablePaymentInfo;
    _enableTableBorder = s.enableTableBorder;
    _enableMinimalInfo = s.enableMinimalInfo;
    _showTimeOnReceipt = s.showTimeOnReceipt;
    _showTaxIncludedPrice = s.showTaxIncludedPrice;
    _printFontSize = s.printFontSize;
    _printLineHeight = s.printLineHeight;
    _invoicePrefixCtrl = TextEditingController(text: s.invoiceIdPrefix);
    _lastInvoiceIdCtrl = TextEditingController(text: s.lastInvoiceId.toString());
    _lastOrderIdCtrl = TextEditingController(text: s.lastOrderId.toString());
    _taxLabelCtrl = TextEditingController(text: s.customTaxLabel);
    _payableLabelCtrl = TextEditingController(text: s.customPayableLabel);
    _attachQrCode = s.attachQrCode;
    _qrDataCtrl = TextEditingController(text: s.qrCodeData);
    _receiptTemplate = s.receiptTemplate;
    _receiptTitleCtrl = TextEditingController(text: s.receiptTitle);
    _receiptFooterCtrl = TextEditingController(text: s.receiptFooter);
    _shopNameCtrl = TextEditingController(text: s.shopName);
    _shopAddressCtrl = TextEditingController(text: s.shopAddress);
    _shopPhoneCtrl = TextEditingController(text: s.shopPhone);
  }

  @override
  void dispose() {
    _tab.dispose();
    _invoicePrefixCtrl.dispose();
    _lastInvoiceIdCtrl.dispose();
    _lastOrderIdCtrl.dispose();
    _taxLabelCtrl.dispose();
    _payableLabelCtrl.dispose();
    _qrDataCtrl.dispose();
    _receiptTitleCtrl.dispose();
    _receiptFooterCtrl.dispose();
    _shopNameCtrl.dispose();
    _shopAddressCtrl.dispose();
    _shopPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAll() async {
    final cubit = context.read<AppSettingsCubit>();
    await cubit.setReceiptSettings(
      textOnlyPrint: _textOnlyPrint,
      sortItemsAlphabetical: _sortItemsAlphabetical,
      printCustomerInfo: _printCustomerInfo,
      printSalesmanName: _printSalesmanName,
      enablePaymentInfo: _enablePaymentInfo,
      enableTableBorder: _enableTableBorder,
      enableMinimalInfo: _enableMinimalInfo,
      showTimeOnReceipt: _showTimeOnReceipt,
      showTaxIncludedPrice: _showTaxIncludedPrice,
      printFontSize: _printFontSize,
      printLineHeight: _printLineHeight,
      invoiceIdPrefix: _invoicePrefixCtrl.text.trim(),
      lastInvoiceId: int.tryParse(_lastInvoiceIdCtrl.text.trim()) ?? 1,
      lastOrderId: int.tryParse(_lastOrderIdCtrl.text.trim()) ?? 1,
      customTaxLabel: _taxLabelCtrl.text.trim().isEmpty ? 'ট্যাক্স' : _taxLabelCtrl.text.trim(),
      customPayableLabel: _payableLabelCtrl.text.trim().isEmpty ? 'পরিশোধযোগ্য' : _payableLabelCtrl.text.trim(),
      attachQrCode: _attachQrCode,
      qrCodeData: _qrDataCtrl.text.trim(),
    );
    await cubit.setReceiptTemplate(_receiptTemplate);
    await cubit.setReceiptTitles(
      receiptTitle: _receiptTitleCtrl.text.trim().isEmpty ? 'বিক্রয় চালান' : _receiptTitleCtrl.text.trim(),
      receiptFooter: _receiptFooterCtrl.text.trim(),
      shopName: _shopNameCtrl.text.trim().isEmpty ? 'আমার দোকান' : _shopNameCtrl.text.trim(),
      shopAddress: _shopAddressCtrl.text.trim(),
      shopPhone: _shopPhoneCtrl.text.trim(),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Receipt Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(Icons.print_outlined, color: _kNavy, size: 26),
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Container(
              color: _surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Enable text only print',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          'Text only print mode can print only english language\nbut printing will fast, support most type of printers',
                          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: _textOnlyPrint,
                    onChanged: (v) => setState(() => _textOnlyPrint = v),
                    activeColor: _kNavy,
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              minHeight: 48,
              maxHeight: 48,
              child: Container(
                color: _surface,
                child: TabBar(
                  controller: _tab,
                  labelColor: _kNavy,
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  indicatorColor: _kNavy,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
                  tabs: const [
                    Tab(text: 'Basic'),
                    Tab(text: 'Templates'),
                    Tab(text: 'Receipt Titles'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _buildBasicTab(),
            _buildTemplatesTab(),
            _buildReceiptTitlesTab(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          width: double.infinity,
          color: _surface,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: _saveAll,
              child: const Text('Okay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }

  // ── Basic Tab ────────────────────────────────────────────────────────────

  Widget _buildBasicTab() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Toggle rows
        _toggleRow('Sort items alphabetical in receipt', _sortItemsAlphabetical,
            (v) => setState(() => _sortItemsAlphabetical = v)),
        _divider(),
        _toggleRow('Print customer info in receipt', _printCustomerInfo,
            (v) => setState(() => _printCustomerInfo = v)),
        _divider(),
        _toggleRow('Print sales man name in bill', _printSalesmanName,
            (v) => setState(() => _printSalesmanName = v)),
        _divider(),
        _toggleRow('Enable payment info in bill', _enablePaymentInfo,
            (v) => setState(() => _enablePaymentInfo = v)),
        _divider(),
        _toggleRow('Enable table border', _enableTableBorder,
            (v) => setState(() => _enableTableBorder = v)),
        _divider(),
        _toggleRow('Enable minimal info in bill', _enableMinimalInfo,
            (v) => setState(() => _enableMinimalInfo = v)),
        _divider(),
        _toggleRow('Show time on receipt', _showTimeOnReceipt,
            (v) => setState(() => _showTimeOnReceipt = v)),
        _divider(),
        _toggleRow('Show tax included price in receipt lines', _showTaxIncludedPrice,
            (v) => setState(() => _showTaxIncludedPrice = v)),

        // Font size slider
        _sliderSection('Print font size', _printFontSize,
            (v) => setState(() => _printFontSize = v)),
        _divider(),

        // Line height slider
        _sliderSection('Print line height', _printLineHeight,
            (v) => setState(() => _printLineHeight = v)),

        const SizedBox(height: 8),

        // Input fields
        _inputRow('INVOICE ID PREFIX', _invoicePrefixCtrl, () {
          _saveField(invoiceIdPrefix: _invoicePrefixCtrl.text.trim());
        }),
        _inputRow('LAST INVOICE ID', _lastInvoiceIdCtrl, () {
          _saveField(lastInvoiceId: int.tryParse(_lastInvoiceIdCtrl.text.trim()) ?? 1);
        }, keyboardType: TextInputType.number),
        _inputRow('LAST ORDER ID', _lastOrderIdCtrl, () {
          _saveField(lastOrderId: int.tryParse(_lastOrderIdCtrl.text.trim()) ?? 1);
        }, keyboardType: TextInputType.number),

        // Info box
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4FD),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBBDEFB)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 18, color: Color(0xFF1565C0)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Use </br> in between words for new line in receipt',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                ),
              ),
            ],
          ),
        ),

        // Tax info text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'You can set custom name for Tax that print in receipt\neg VAT(5%%), GST(18%%) ..etc',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
          ),
        ),

        // Custom label for tax
        _inputRow('CUSTOM LABEL FOR TAX', _taxLabelCtrl, () {
          _saveField(customTaxLabel: _taxLabelCtrl.text.trim().isEmpty ? 'ট্যাক্স' : _taxLabelCtrl.text.trim());
        }),
        _inputRow('CUSTOM NAME FOR PAYABLE', _payableLabelCtrl, () {
          _saveField(customPayableLabel: _payableLabelCtrl.text.trim().isEmpty ? 'পরিশোধযোগ্য' : _payableLabelCtrl.text.trim());
        }),

        // Attach QR code toggle row
        Container(
          color: _surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: _toggleRow('Attach Qr Code', _attachQrCode,
                    (v) => setState(() => _attachQrCode = v), inline: true),
              ),
            ],
          ),
        ),
        _divider(),

        // QR code data text area
        if (_attachQrCode) ...[
          Container(
            color: _surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enter QR code data',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                TextField(
                  controller: _qrDataCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: _outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: _outline),
                    ),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
              ],
            ),
          ),
          _divider(),
        ],

        const SizedBox(height: 16),
      ],
    );
  }

  // ── Templates Tab ────────────────────────────────────────────────────────

  Widget _buildTemplatesTab() {
    final shop = _shopNameCtrl.text.trim().isEmpty ? 'আমার দোকান' : _shopNameCtrl.text.trim();
    final addr = _shopAddressCtrl.text.trim();
    final phone = _shopPhoneCtrl.text.trim();

    final templates = <_TplData>[
      _TplData(1, 'Detailed POS', _previewDetailedPOS(shop, addr, phone)),
      _TplData(0, 'Standard', _previewStandard(shop, addr, phone)),
      _TplData(2, 'Big Font', _previewBigFont(shop, addr, phone)),
      _TplData(3, 'QR Code', _previewQrCode(shop, addr, phone)),
      _TplData(4, 'Barcode', _previewBarcode(shop, addr, phone)),
      _TplData(5, 'Ticket', _previewTicket(shop, addr, phone)),
      _TplData(6, 'A4-Style 1', _previewA4Style1(shop, addr, phone)),
    ];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 280, // Fixed height to make them look like long receipts
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _templatePreviewCard(templates[index]),
              childCount: templates.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  Widget _templatePreviewCard(_TplData t) {
    final selected = _receiptTemplate == t.index;
    return GestureDetector(
      onTap: () => setState(() => _receiptTemplate = t.index),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          border: Border.symmetric(horizontal: BorderSide(color: _outline)),
        ),
        child: Column(
          children: [
            // Receipt preview area — POS machine style
            Expanded(
              child: GestureDetector(
                onTap: () => _showFullScreenPreview(context, t),
                child: Container(
                  color: Theme.of(context).colorScheme.surface,
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                  margin: const EdgeInsets.all(8),
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 220, // Narrow width like POS receipt
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        )
                      ]
                    ),
                    padding: const EdgeInsets.all(12),
                    child: t.preview,
                  ),
                ),
              ),
            ),
            ),
            // Selection row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(t.name,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected ? _kNavy : null)),
                  ),
                  SizedBox(
                    height: 24,
                    child: Switch(
                      value: selected,
                      onChanged: (v) {
                        if (v) setState(() => _receiptTemplate = t.index);
                      },
                      activeColor: _kNavy,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenPreview(BuildContext context, _TplData t) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            AppBar(
                backgroundColor: Colors.transparent,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                elevation: 0,
                title: Text(t.name, style: const TextStyle(fontSize: 16)),
                leading: null,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Center(
                  child: Container(
                    width: 280, // Slightly wider for full screen readability
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    ),
                    child: t.preview,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    setState(() => _receiptTemplate = t.index);
                    Navigator.pop(context);
                  },
                  child: Text(_receiptTemplate == t.index ? 'Selected' : 'Select This Template'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Template Previews ─────────────────────────────────────────────────────

  static const _sampleItems = [
    ('Product A', 2, 120.0),
    ('Product B', 1, 85.0),
    ('Product C', 3, 50.0),
  ];

  Widget _previewStandard(String shop, String addr, String phone) {
    return _PreviewReceipt(
      shopName: shop,
      shopAddr: addr,
      shopPhone: phone,
      title: 'বিক্রয় চালান',
      showStoreIcon: true,
      header: _previewMetaRows([
        ('Invoice No:', 'INV-001'),
        ('Date:', '24/06/2026'),
      ]),
      itemsHeader: _previewTableHeader(['#', 'Item', 'Price', 'Qty', 'Amt']),
      itemRows: _previewItemRows(),
      summary: _previewSummaryRows([
        ('Price Amount', '৳405.00'),
        ('Bill Amount', '৳405.00'),
        ('Paid', '৳405.00'),
        ('Payment Method', 'Cash'),
      ]),
    );
  }

  Widget _previewDetailedPOS(String shop, String addr, String phone) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pText(shop, bold: true, size: 13, align: TextAlign.center),
        if (addr.isNotEmpty) _pText(addr, size: 9, align: TextAlign.center),
        if (phone.isNotEmpty) _pText(phone, size: 9, align: TextAlign.center),
        const SizedBox(height: 4),
        Container(height: 1, color: cs.onSurface),
        const SizedBox(height: 3),
        _pText('Inv No: INV-001  Date: 24/06/2026  Payment: CASH', size: 8),
        const SizedBox(height: 3),
        Table(
          border: TableBorder.all(width: 0.5, color: cs.outlineVariant),
          columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2), 3: FlexColumnWidth(2)},
          children: [
            _tRow(['Item Description', 'Price', 'Disc', 'Amt'], header: true),
            for (final i in _sampleItems) ...[
              _tRow([i.$1, '৳${i.$3.toStringAsFixed(0)}', '0.00', '৳${(i.$2 * i.$3).toStringAsFixed(0)}']),
              _tRow(['${i.$2}', '', '', ''], small: true),
            ],
            _tRow(['Total Qty: 6', '', 'Total Items: 3', ''], small: true),
          ],
        ),
        const SizedBox(height: 3),
        _pRow('Sub Total', '৳405.00'),
        _pRow('Grand Total', '৳405.00', bold: true),
        _pRow('Payable', '৳405.00'),
        const SizedBox(height: 3),
        Container(height: 1, color: cs.outlineVariant),
        _pText('Payment Information', bold: true, size: 9),
        Table(
          border: TableBorder.all(width: 0.5, color: cs.outlineVariant),
          children: [
            _tRow(['Date', 'Paid', 'Due'], header: true),
            _tRow(['24-06-2026', '৳405.00(CASH)', '৳0.00']),
          ],
        ),
      ],
    );
  }

  Widget _previewBigFont(String shop, String addr, String phone) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pText(shop, bold: true, size: 14, align: TextAlign.center),
        if (addr.isNotEmpty) _pText(addr, size: 10, align: TextAlign.center),
        if (phone.isNotEmpty) _pText(phone, size: 10, align: TextAlign.center),
        _pText('বিক্রয় চালান', bold: true, size: 12, align: TextAlign.center),
        Container(height: 1, color: cs.onSurface, margin: const EdgeInsets.symmetric(vertical: 4)),
        _pText('Invoice Details', bold: true, size: 11),
        _pText('Order ID: INV-001', size: 10),
        _pText('Date: 24/06/2026  Payment: Cash', size: 10),
        Container(height: 0.5, color: cs.outlineVariant, margin: const EdgeInsets.symmetric(vertical: 4)),
        Row(children: [
          Expanded(child: _pText('Item', bold: true, size: 11)),
          _pText('Amt', bold: true, size: 11),
        ]),
        for (final i in _sampleItems) ...[
          Container(height: 0.5, color: cs.outlineVariant),
          Row(children: [
            Expanded(child: _pText(i.$1, size: 11)),
            _pText('৳${(i.$2 * i.$3).toStringAsFixed(0)}', bold: true, size: 11),
          ]),
          _pText('${i.$2} X ৳${i.$3.toStringAsFixed(0)}', size: 9, color: cs.onSurfaceVariant),
        ],
        Container(height: 1, color: cs.onSurface, margin: const EdgeInsets.symmetric(vertical: 3)),
        _pRow('Sub Total', '৳405.00', size: 12),
        _pRow('Payable', '৳405.00', size: 12, bold: true),
      ],
    );
  }

  Widget _previewQrCode(String shop, String addr, String phone) {
    return Column(children: [
      _previewStandard(shop, addr, phone),
      const SizedBox(height: 6),
      Center(
        child: CustomPaint(
          size: const Size(70, 70),
          painter: _QrPainter(),
        ),
      ),
      _pText('INV-001', size: 8, align: TextAlign.center),
    ]);
  }

  Widget _previewBarcode(String shop, String addr, String phone) {
    return Column(children: [
      _previewStandard(shop, addr, phone),
      const SizedBox(height: 6),
      Center(
        child: CustomPaint(
          size: const Size(120, 40),
          painter: _BarcodePainter(),
        ),
      ),
      _pText('INV-001', size: 8, align: TextAlign.center),
    ]);
  }

  Widget _previewTicket(String shop, String addr, String phone) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _pText(shop, bold: true, size: 20, align: TextAlign.center),
        if (addr.isNotEmpty) _pText(addr, size: 10, align: TextAlign.center),
        if (phone.isNotEmpty) _pText(phone, size: 10, align: TextAlign.center),
        const SizedBox(height: 6),
        _pText('Ticket: INV-001  Date: 24/06/2026', bold: true, size: 10, align: TextAlign.center),
        const SizedBox(height: 6),
        for (final i in _sampleItems.take(2))
          Container(
            margin: const EdgeInsets.only(bottom: 0),
            decoration: BoxDecoration(border: Border.all(width: 1.5, color: cs.onSurface)),
            child: Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: _pText(i.$1, size: 11),
              ),
              Container(
                decoration: BoxDecoration(border: Border(top: BorderSide(width: 1.5, color: cs.onSurface))),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(children: [
                  Expanded(child: _pText('${i.$2}.0 X ${i.$3.toStringAsFixed(0)}', size: 11)),
                  _pText('${(i.$2 * i.$3).toStringAsFixed(0)}', bold: true, size: 11),
                ]),
              ),
            ]),
          ),
        Container(
          decoration: BoxDecoration(border: Border.all(width: 1.5, color: cs.onSurface)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [
            Expanded(child: _pText('BDT', bold: true, size: 13)),
            _pText('৳405.00', bold: true, size: 18),
          ]),
        ),
      ],
    );
  }

  Widget _previewA4Style1(String shop, String addr, String phone) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pText(shop, bold: true, size: 14, align: TextAlign.center),
        if (addr.isNotEmpty) _pText(addr, size: 9, align: TextAlign.center),
        if (phone.isNotEmpty) _pText(phone, size: 9, align: TextAlign.center),
        Container(height: 2, color: cs.onSurface, margin: const EdgeInsets.symmetric(vertical: 5)),
        _pText('Invoice Details', bold: true, size: 11),
        _pText('Order ID: INV-001', size: 9),
        _pText('Date: 24/06/2026  Payment: Cash', size: 9),
        Container(height: 0.5, color: cs.outlineVariant, margin: const EdgeInsets.symmetric(vertical: 4)),
        Table(
          border: TableBorder.all(width: 0.5, color: cs.outlineVariant),
          columnWidths: const {0: FixedColumnWidth(22), 1: FlexColumnWidth(3), 2: FlexColumnWidth(2), 3: FixedColumnWidth(22), 4: FlexColumnWidth(2)},
          children: [
            _tRow(['#', 'Item', 'Price', 'Qty', 'Total'], header: true),
            for (int i = 0; i < _sampleItems.length; i++)
              _tRow(['${i + 1}', _sampleItems[i].$1, '৳${_sampleItems[i].$3.toStringAsFixed(0)}', '${_sampleItems[i].$2}', '৳${(_sampleItems[i].$2 * _sampleItems[i].$3).toStringAsFixed(0)}']),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          alignment: Alignment.centerRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _pRow('Sub Total', '৳405.00', size: 9),
              Container(height: 2, color: cs.onSurface, margin: const EdgeInsets.symmetric(vertical: 2)),
              _pRow('Grand Total', '৳405.00', bold: true, size: 11),
              _pRow('Paid', '৳405.00', size: 9),
            ],
          ),
        ),
      ],
    );
  }

  // ── Preview helpers ───────────────────────────────────────────────────────

  Widget _pText(String text, {bool bold = false, double size = 10, TextAlign align = TextAlign.start, Color? color}) =>
      Text(text, textAlign: align, style: TextStyle(fontSize: size, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color));

  Widget _pRow(String label, String value, {bool bold = false, double size = 10}) =>
      Row(children: [
        Expanded(child: _pText(label, size: size)),
        _pText(value, bold: bold, size: size),
      ]);

  TableRow _tRow(List<String> cells, {bool header = false, bool small = false}) =>
      TableRow(
        decoration: header ? BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHigh) : null,
        children: cells.map((c) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Text(c, style: TextStyle(fontSize: small ? 7 : 8, fontWeight: header ? FontWeight.bold : FontWeight.normal, color: Theme.of(context).colorScheme.onSurface)),
        )).toList(),
      );

  Widget _previewMetaRows(List<(String, String)> rows) =>
      Column(children: rows.map((r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text(r.$1, style: const TextStyle(fontSize: 9)),
          const Spacer(),
          Text(r.$2, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
        ]),
      )).toList());

  Widget _previewTableHeader(List<String> cols) =>
      Row(children: [
        SizedBox(width: 14, child: Text(cols[0], style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
        const SizedBox(width: 4),
        Expanded(child: Text(cols[1], style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
        SizedBox(width: 40, child: Text(cols[2], textAlign: TextAlign.right, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
        SizedBox(width: 24, child: Text(cols[3], textAlign: TextAlign.center, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
        SizedBox(width: 40, child: Text(cols[4], textAlign: TextAlign.right, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
      ]);

  Widget _previewItemRows() => Column(children: _sampleItems.asMap().entries.map((e) {
    final i = e.key;
    final item = e.value;
    return Column(children: [
      Container(height: 0.5, color: Theme.of(context).colorScheme.outlineVariant),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 9))),
          const SizedBox(width: 4),
          Expanded(child: Text(item.$1, style: const TextStyle(fontSize: 9))),
          SizedBox(width: 40, child: Text('৳${item.$3.toStringAsFixed(0)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 9))),
          SizedBox(width: 24, child: Text('${item.$2}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 9))),
          SizedBox(width: 40, child: Text('৳${(item.$2 * item.$3).toStringAsFixed(0)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
        ]),
      ),
    ]);
  }).toList());

  Widget _previewSummaryRows(List<(String, String)> rows) => Column(children: rows.map((r) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(child: Text(r.$1, style: const TextStyle(fontSize: 9))),
        Text(r.$2, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
      ]),
    )
  ).toList());

  // ── Receipt Titles Tab ───────────────────────────────────────────────────

  Widget _buildReceiptTitlesTab() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _titlesInputRow('SHOP NAME', _shopNameCtrl, hint: 'আমার দোকান'),
        _divider(),
        _titlesInputRow('SHOP ADDRESS', _shopAddressCtrl, hint: 'দোকানের ঠিকানা', maxLines: 2),
        _divider(),
        _titlesInputRow('SHOP PHONE', _shopPhoneCtrl, hint: '০১XXXXXXXXX', keyboardType: TextInputType.phone),
        _divider(),
        _titlesInputRow('RECEIPT TITLE', _receiptTitleCtrl, hint: 'বিক্রয় চালান'),
        _divider(),
        _titlesInputRow('FOOTER TEXT', _receiptFooterCtrl, hint: 'ধন্যবাদ আবার আসবেন', maxLines: 3),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChange,
      {bool inline = false}) {
    final content = Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Switch(
          value: value,
          onChanged: onChange,
          activeColor: _kNavy,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
    if (inline) return content;
    return Container(
      color: _surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: content,
    );
  }

  Widget _sliderSection(String label, double value, ValueChanged<double> onChange) {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbColor: _kNavy,
              activeTrackColor: _kNavy,
              inactiveTrackColor: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(value: value, onChanged: onChange),
          ),
        ],
      ),
    );
  }

  Widget _inputRow(String label, TextEditingController ctrl, VoidCallback onOkay,
      {TextInputType? keyboardType}) {
    return Container(
      color: _surface,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4)),
                const SizedBox(height: 4),
                TextField(
                  controller: ctrl,
                  keyboardType: keyboardType,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 38,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                elevation: 0,
              ),
              onPressed: onOkay,
              child: const Text('Okay', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _titlesInputRow(String label, TextEditingController ctrl,
      {String? hint, TextInputType? keyboardType, int maxLines = 1}) {
    return Container(
      color: _surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              filled: true,
              fillColor: _bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _kNavy),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(height: 1, color: _outline);

  // Save a single field immediately (Okay button per field)
  void _saveField({
    String? invoiceIdPrefix,
    int? lastInvoiceId,
    int? lastOrderId,
    String? customTaxLabel,
    String? customPayableLabel,
  }) {
    context.read<AppSettingsCubit>().setReceiptSettings(
          invoiceIdPrefix: invoiceIdPrefix,
          lastInvoiceId: lastInvoiceId,
          lastOrderId: lastOrderId,
          customTaxLabel: customTaxLabel,
          customPayableLabel: customPayableLabel,
        );
  }
}

class _TplData {
  final int index;
  final String name;
  final Widget preview;
  const _TplData(this.index, this.name, this.preview);
}

// ── Receipt preview compound widget ──────────────────────────────────────────

class _PreviewReceipt extends StatelessWidget {
  final String shopName;
  final String shopAddr;
  final String shopPhone;
  final String title;
  final bool showStoreIcon;
  final Widget? header;
  final Widget? itemsHeader;
  final Widget? itemRows;
  final Widget? summary;

  const _PreviewReceipt({
    required this.shopName,
    required this.shopAddr,
    required this.shopPhone,
    required this.title,
    this.showStoreIcon = false,
    this.header,
    this.itemsHeader,
    this.itemRows,
    this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showStoreIcon)
          const Icon(Icons.store_mall_directory_outlined, size: 28, color: AppColors.primary),
        Text(shopName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        if (shopAddr.isNotEmpty)
          Text(shopAddr, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8)),
        if (shopPhone.isNotEmpty)
          Text(shopPhone, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8)),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        _dash(context),
        if (header != null) ...[header!, _dash(context)],
        if (itemsHeader != null) ...[const SizedBox(height: 3), itemsHeader!],
        if (itemRows != null) itemRows!,
        if (summary != null) ...[const SizedBox(height: 4), summary!],
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _dash(BuildContext context) => CustomPaint(
    size: const Size(double.infinity, 1),
    painter: _DashLinePainter(color: Theme.of(context).colorScheme.outlineVariant),
  );
}

class _DashLinePainter extends CustomPainter {
  final Color color;
  _DashLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 0.5;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset((x + 3).clamp(0, size.width), 0), paint);
      x += 5;
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _QrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black;
    final cell = size.width / 7;
    _finder(canvas, p, 0, 0, cell);
    _finder(canvas, p, 4 * cell, 0, cell);
    _finder(canvas, p, 0, 4 * cell, cell);
    final cells = [[2, 2], [3, 3], [2, 4], [4, 2], [3, 5], [5, 3], [4, 4], [5, 5], [6, 4]];
    for (final c in cells) {
      canvas.drawRect(Rect.fromLTWH(c[0] * cell, c[1] * cell, cell - 0.5, cell - 0.5), p);
    }
  }

  void _finder(Canvas canvas, Paint p, double x, double y, double cell) {
    canvas.drawRect(Rect.fromLTWH(x, y, 3 * cell, 3 * cell), p);
    canvas.drawRect(Rect.fromLTWH(x + 0.5, y + 0.5, 3 * cell - 1, 3 * cell - 1),
        Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(x + cell, y + cell, cell, cell), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _BarcodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black;
    final bars = [3, 1, 2, 1, 3, 1, 1, 2, 1, 3, 2, 1, 1, 3, 1, 2, 1, 1, 3, 2, 1, 3, 1, 1, 2];
    double x = 0;
    bool isBar = true;
    final total = bars.fold(0, (a, b) => a + b).toDouble();
    for (final w in bars) {
      final barW = (w / total) * size.width;
      if (isBar) {
        canvas.drawRect(Rect.fromLTWH(x, 0, barW - 0.5, size.height), p);
      }
      x += barW;
      isBar = !isBar;
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight > minHeight ? maxHeight : minHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
