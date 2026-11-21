import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../viewmodels/auth_view_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authViewModel});

  final AuthViewModel authViewModel;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AuthViewModel get _authViewModel => widget.authViewModel;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    try {
      await _authViewModel.signInWithGoogle();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _authViewModel,
      builder: (context, _) {
        final theme = Theme.of(context);
        final isBusy = _authViewModel.isBusy;

        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE8F4F1),
                  Color(0xFFF5F8FC),
                  Color(0xFFEAF1F5),
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            
                            const SizedBox(height: 20),
                            Align(
  alignment: Alignment.center,
  child: ShaderMask(
    // Creates a colorful gradient effect across the text
    shaderCallback: (bounds) => const LinearGradient(
      colors: [
        AppColors.brandPrimary,
        AppColors.revenueDark,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(bounds),
    child: Text(
      'STAYCAY OWNER',
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w900, // Extra bold for brand identity
        color: Colors.white, // Required white background for the gradient mask
        letterSpacing: 2.0, // Spaced letters look more like a premium logo
      ),
    ),
  ),
),
                            const SizedBox(height: 8),
                            Text(
                              textAlign: TextAlign.center,
                              'Sign in with your Google account',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF64748B),
                                height: 1.4,
                              ),
                            ),
                            if (_authViewModel.errorMessage != null) ...[
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  _authViewModel.errorMessage!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: isBusy ? null : _signInWithGoogle,
                              icon: const Icon(Icons.login),
                              label: const Text('Continue with Google'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
