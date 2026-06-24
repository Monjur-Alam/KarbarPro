import 'package:flutter/material.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  String _portType = 'Bluetooth';
  String _paperWidth = '56mm';
  String? _selectedPrinter;

  final List<String> _dummyPrinters = [
    'AWEI A997 Pro ANC',
    'OnePlus Bullets Wireless Z2',
  ];

  void _showPrinterSelectionModal() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: const Color(0xFF1F124E), // Dark blue like the screenshot
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: const Text(
                  'Opt BT Device',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'Paired Device',
                  style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
              const Divider(height: 1),
              ..._dummyPrinters.map((printer) => Column(
                children: [
                  ListTile(
                    title: Text(printer, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    onTap: () {
                      setState(() => _selectedPrinter = printer);
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(height: 1),
                ],
              )),
              ListTile(
                title: Text('Search Devices', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
                onTap: () {
                  // Add scan functionality later
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('CANCEL', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Background colors matching the screenshot
    final cardBgColor = isDark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFFEBEBEB);
    final headerBgColor = const Color(0xFF1F124E); // Deep purple/blue header

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: headerBgColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header section
          Container(
            width: double.infinity,
            color: headerBgColor,
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                const Icon(Icons.print_outlined, color: Colors.white, size: 48),
                const SizedBox(height: 8),
                const Text(
                  'Printer settings',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Port Type Card
                  Container(
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Port Type',
                          style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface),
                        ),
                        const SizedBox(height: 12),
                        _buildRadioRow('Bluetooth', _portType, (v) => setState(() => _portType = v!)),
                        const SizedBox(height: 8),
                        _buildRadioRow('USB', _portType, (v) => setState(() => _portType = v!)),
                        const SizedBox(height: 8),
                        _buildRadioRow('WIFI', _portType, (v) => setState(() => _portType = v!)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Paper width and Printer Selection Card
                  Container(
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paper width',
                          style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildRadioRow('56mm', _paperWidth, (v) => setState(() => _paperWidth = v!))),
                            Expanded(child: _buildRadioRow('80mm', _paperWidth, (v) => setState(() => _paperWidth = v!))),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Choose printer',
                          style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _showPrinterSelectionModal,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? theme.colorScheme.surface : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedPrinter ?? 'Select Printer',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _selectedPrinter == null 
                                        ? Colors.grey 
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Connect Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: headerBgColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        // Implement connect logic
                      },
                      child: const Text('Connect', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioRow(String title, String groupValue, ValueChanged<String?> onChanged) {
    final isSelected = title == groupValue;
    return GestureDetector(
      onTap: () => onChanged(title),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.green : Colors.grey.shade400,
                width: isSelected ? 0 : 2,
              ),
              color: isSelected ? Colors.green : Colors.transparent,
            ),
            child: isSelected 
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
