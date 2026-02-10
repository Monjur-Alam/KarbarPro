import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/drive_service.dart';
import '../models/inventory_data.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final DriveService _driveService = DriveService();
  bool _isSaving = false;
  String? _saveMessage;

  Future<void> _handleSaveToDrive() async {
    setState(() {
      _isSaving = true;
      _saveMessage = null;
    });

    try {
      // Get sample inventory data
      final inventoryReport = InventoryDataHelper.getInventoryReport();

      // Generate filename with timestamp
      final timestamp = DateTime.now().toIso8601String().split('.')[0];
      final fileName = 'amar_dokan_inventory_$timestamp.json';

      // Save to Google Drive
      await _driveService.saveToGoogleDrive(inventoryReport, fileName);

      setState(() {
        _saveMessage = 'Successfully saved to Google Drive!';
      });

      // Clear message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _saveMessage = null;
          });
        }
      });
    } catch (error) {
      setState(() {
        _saveMessage = 'Error: ${error.toString()}';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.userModel;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.purple.shade600],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleSignOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Profile Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // Profile Photo
                      if (user?.photoUrl != null)
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: NetworkImage(user!.photoUrl!),
                          backgroundColor: Colors.grey.shade300,
                        )
                      else
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blue.shade100,
                          child: Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Welcome Message
                      Text(
                        'Welcome!',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // User Name
                      Text(
                        user?.displayName ?? 'User',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // User Email
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.email,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                user?.email ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save to Drive Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.cloud_upload,
                            color: Colors.purple.shade600,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Google Drive Backup',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Save your inventory data to your Google Drive account',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Save Button
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _handleSaveToDrive,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          _isSaving ? 'Saving...' : 'Save to Google Drive',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),

                      // Success/Error Message
                      if (_saveMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _saveMessage!.startsWith('Error')
                                ? Colors.red.shade50
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _saveMessage!.startsWith('Error')
                                    ? Icons.error_outline
                                    : Icons.check_circle_outline,
                                color: _saveMessage!.startsWith('Error')
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _saveMessage!,
                                  style: TextStyle(
                                    color: _saveMessage!.startsWith('Error')
                                        ? Colors.red.shade700
                                        : Colors.green.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Sample Inventory Preview
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.inventory,
                            color: Colors.blue.shade700,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Sample Inventory',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                       ...InventoryDataHelper.getSampleData().map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.itemName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                'Qty: ${item.quantity}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '৳${item.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
