import 'package:amar_dokan/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../bloc/auth_bloc.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF06142F), Color(0xFF0B2F45)],
                ),
              ),
            ),
            Positioned(
              top: -90,
              right: -70,
              child: _GlowOrb(
                size: 260,
                color: AppColors.primary.withValues(alpha: 0.22),
              ),
            ),
            Positioned(
              bottom: -110,
              left: -100,
              child: _GlowOrb(
                size: 300,
                color: AppColors.secondary.withValues(alpha: 0.18),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 64,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.97),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 40,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 104,
                                  height: 104,
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(27),
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        AppColors.secondary,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.25,
                                        ),
                                        blurRadius: 24,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(21),
                                    child: Image.asset(
                                      'assets/branding/karbar-pro-icon-master.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  context.l10n.appName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 30,
                                    height: 1.15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  context.l10n.loginSubtitle,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 15,
                                    height: 1.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                BlocBuilder<AuthBloc, AuthState>(
                                  buildWhen: (previous, current) =>
                                      previous is AuthFailure ||
                                      current is AuthFailure,
                                  builder: (context, state) {
                                    if (state is! AuthFailure) {
                                      return const SizedBox.shrink();
                                    }
                                    return Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.all(13),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFFECACA),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.error_outline_rounded,
                                            size: 20,
                                            color: AppColors.error,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              state.message,
                                              style: const TextStyle(
                                                color: Color(0xFF991B1B),
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                BlocBuilder<AuthBloc, AuthState>(
                                  builder: (context, state) {
                                    final isLoading = state is AuthLoading;
                                    return ElevatedButton(
                                      onPressed: isLoading
                                          ? null
                                          : () => context.read<AuthBloc>().add(
                                              AuthLoginRequested(),
                                            ),
                                      style: ElevatedButton.styleFrom(
                                        elevation: 0,
                                        backgroundColor: Colors.white,
                                        disabledBackgroundColor: const Color(
                                          0xFFF8FAFC,
                                        ),
                                        foregroundColor: const Color(
                                          0xFF1E293B,
                                        ),
                                        minimumSize: const Size.fromHeight(58),
                                        side: const BorderSide(
                                          color: Color(0xFFE2E8F0),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        child: isLoading
                                            ? const SizedBox(
                                                key: ValueKey('loading'),
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      color: AppColors.primary,
                                                    ),
                                              )
                                            : Row(
                                                key: const ValueKey('google'),
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  SvgPicture.asset(
                                                    'assets/branding/google_g_logo.svg',
                                                    width: 23,
                                                    height: 23,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    context
                                                        .l10n
                                                        .signInWithGoogle,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 22),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.lock_outline_rounded,
                                      size: 15,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      context.l10n.isBangla
                                          ? 'নিরাপদ ও সুরক্ষিত সাইন ইন'
                                          : 'Safe and secure sign in',
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
