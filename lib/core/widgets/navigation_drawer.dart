import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(
                  icon: Icons.person_outline,
                  label: 'প্রোফাইল',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                  },
                ),
                _buildMenuItem(
                  icon: Icons.settings_outlined,
                  label: 'সেটিংস',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to Settings
                  },
                ),
                _buildMenuItem(
                  icon: Icons.bar_chart_outlined,
                  label: 'রিপোর্টসমূহ',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to Reports
                  },
                ),
                _buildMenuItem(
                  icon: Icons.backup_outlined,
                  label: 'ব্যাকআপ ও পুনরুদ্ধার',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to Backup
                  },
                ),
                const Divider(),
                _buildMenuItem(
                  icon: Icons.info_outline,
                  label: 'অ্যাপ সম্পর্কে',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to About
                  },
                ),
                _buildMenuItem(
                  icon: Icons.logout,
                  label: 'লগআউট',
                  color: Colors.red,
                  onTap: () => _showLogoutDialog(context),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Version 1.1.0', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        String name = 'ব্যবহারকারী';
        String phone = '';
        
        if (state is AuthAuthenticated) {
          name = state.user.displayName ?? 'ব্যবহারকারী';
          phone = state.user.email ?? ''; // Using email if phone not available
        }

        return UserAccountsDrawerHeader(
          accountName: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          accountEmail: Text(phone),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Colors.white,
            child: Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
          ),
          decoration: BoxDecoration(
            color: Colors.teal.shade700,
          ),
        );
      },
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.blueGrey),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('লগআউট'),
        content: const Text('আপনি কি নিশ্চিতভাবে লগআউট করতে চান?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('না')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
            child: const Text('হ্যাঁ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
