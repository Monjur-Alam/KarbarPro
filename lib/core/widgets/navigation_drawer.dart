import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';
import '../constants/app_colors.dart';
import '../database/database_helper.dart';
import '../l10n/app_localizations.dart';
import '../services/google_drive_service.dart';
import '../settings/app_settings_cubit.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations(locale);

    return Drawer(
      child: Column(
        children: [
          _buildHeader(context, l10n),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildExpandableLanguage(context, l10n, isDark),
                _buildExpandableTheme(context, l10n, isDark),
                const Divider(height: 1),
                _buildMenuItem(
                  context: context,
                  icon: Icons.person_outline,
                  label: l10n.profile,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                  isDark: isDark,
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.settings_outlined,
                  label: l10n.settings,
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to Settings
                  },
                  isDark: isDark,
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.bar_chart_outlined,
                  label: l10n.reports,
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to Reports
                  },
                  isDark: isDark,
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.backup_outlined,
                  label: l10n.backupRestore,
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to Backup
                  },
                  isDark: isDark,
                ),
                const Divider(height: 1),
                _buildMenuItem(
                  context: context,
                  icon: Icons.info_outline,
                  label: l10n.about,
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to About
                  },
                  isDark: isDark,
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.delete_forever_outlined,
                  label: l10n.resetData,
                  color: theme.colorScheme.error,
                  onTap: () => _showResetDataDialog(context, l10n),
                  isDark: isDark,
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.logout,
                  label: l10n.logout,
                  color: theme.colorScheme.error,
                  onTap: () => _showLogoutDialog(context, l10n),
                  isDark: isDark,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              'Version 1.1.0',
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        String name = l10n.user;
        String phone = '';

        if (state is AuthAuthenticated) {
          name = state.user.displayName ?? l10n.user;
          phone = state.user.email ?? '';
        }

        return UserAccountsDrawerHeader(
          accountName: Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          accountEmail: Text(
            phone,
            style: const TextStyle(fontSize: 13),
          ),
          currentAccountPicture: CircleAvatar(
            backgroundColor: theme.colorScheme.surface,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          decoration: BoxDecoration(
            color: AppColors.primary,
          ),
        );
      },
    );
  }

  Widget _buildExpandableLanguage(
    BuildContext context,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final iconColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return BlocBuilder<AppSettingsCubit, AppSettingsState>(
      builder: (context, state) {
        final currentLocale = state.locale;

        return ExpansionTile(
          leading: Icon(
            Icons.language_rounded,
            color: iconColor,
            size: 24,
          ),
          title: Text(
            l10n.language,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: iconColor,
              fontSize: 15,
            ),
          ),
          iconColor: iconColor,
          collapsedIconColor: iconColor,
          childrenPadding: const EdgeInsets.only(left: 24, bottom: 8),
          children: [
            _buildLanguageOption(
              context,
              label: l10n.bangla,
              isSelected: currentLocale.languageCode == 'bn',
              onTap: () {
                context.read<AppSettingsCubit>().setLocale(const Locale('bn', 'BD'));
              },
              isDark: isDark,
            ),
            _buildLanguageOption(
              context,
              label: l10n.english,
              isSelected: currentLocale.languageCode == 'en',
              onTap: () {
                context.read<AppSettingsCubit>().setLocale(const Locale('en', 'US'));
              },
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageOption(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: textColor,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
          : null,
      onTap: onTap,
    );
  }

  Widget _buildExpandableTheme(
    BuildContext context,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final iconColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return BlocBuilder<AppSettingsCubit, AppSettingsState>(
      builder: (context, state) {
        final currentMode = state.themeMode;

        return ExpansionTile(
          leading: Icon(
            Icons.palette_outlined,
            color: iconColor,
            size: 24,
          ),
          title: Text(
            l10n.theme,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: iconColor,
              fontSize: 15,
            ),
          ),
          iconColor: iconColor,
          collapsedIconColor: iconColor,
          childrenPadding: const EdgeInsets.only(left: 24, bottom: 8),
          children: [
            _buildThemeOption(
              context,
              label: l10n.light,
              icon: Icons.light_mode_rounded,
              isSelected: currentMode == AppThemeMode.light,
              onTap: () {
                context.read<AppSettingsCubit>().setThemeMode(AppThemeMode.light);
              },
              isDark: isDark,
            ),
            _buildThemeOption(
              context,
              label: l10n.dark,
              icon: Icons.dark_mode_rounded,
              isSelected: currentMode == AppThemeMode.dark,
              onTap: () {
                context.read<AppSettingsCubit>().setThemeMode(AppThemeMode.dark);
              },
              isDark: isDark,
            ),
            _buildThemeOption(
              context,
              label: l10n.systemDefault,
              icon: Icons.brightness_auto_rounded,
              isSelected: currentMode == AppThemeMode.system,
              onTap: () {
                context.read<AppSettingsCubit>().setThemeMode(AppThemeMode.system);
              },
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Icon(icon, size: 20, color: textColor),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: textColor,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
          : null,
      onTap: onTap,
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final iconColor = color ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary);
    final textColor = color ?? iconColor;

    return ListTile(
      leading: Icon(icon, color: iconColor, size: 24),
      title: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showResetDataDialog(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Text(l10n.resetDataConfirmTitle),
          ],
        ),
        content: Text(l10n.resetDataConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performResetData(context, l10n);
            },
            child: Text(
              l10n.resetDataButton,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performResetData(BuildContext context, AppLocalizations l10n) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Clear all SQLite tables
      final dbHelper = context.read<DatabaseHelper>();
      await dbHelper.clearAllTables();

      // Try to delete all Google Drive backups
      try {
        final driveService = context.read<GoogleDriveService>();
        final folderId = await driveService.getOrCreateBackupFolder();
        final backups = await driveService.listBackups(folderId);
        for (final file in backups) {
          if (file.id != null) {
            await driveService.deleteFile(file.id!);
          }
        }
      } catch (_) {
        // Ignore drive errors (user may be offline)
      }

      // Dismiss loading dialog
      if (context.mounted) Navigator.pop(context);

      // Close the drawer
      if (context.mounted) Navigator.pop(context);

      // Show success snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.resetDataSuccess)),
        );
      }

      // Logout the user
      if (context.mounted) {
        context.read<AuthBloc>().add(AuthLogoutRequested());
      }
    } catch (e) {
      // Dismiss loading dialog
      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorPrefix}$e')),
        );
      }
    }
  }

  void _showLogoutDialog(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.no),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
            child: Text(l10n.yes, style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );
  }
}
