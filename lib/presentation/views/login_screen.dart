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
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _usingEmail = false;
  bool _creatingAccount = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    try {
      await _authViewModel.signInWithGoogle();
    } catch (_) {
      // The view model exposes the error to the screen.
    }
  }

  void _switchMode({required bool email, bool create = false}) {
    _authViewModel.clearError();
    setState(() {
      _usingEmail = email;
      _creatingAccount = create;
      _password.clear();
      _confirmPassword.clear();
      _showPassword = false;
    });
  }

  Future<void> _submitEmail() async {
    if (_authViewModel.isBusy ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    try {
      if (_creatingAccount) {
        await _authViewModel.createAccountWithEmail(
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await _authViewModel.signInWithEmail(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } catch (_) {
      // The view model exposes the error to the screen.
    }
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
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
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
                                    fontWeight: FontWeight
                                        .w900, // Extra bold for brand identity
                                    color: Colors
                                        .white, // Required white background for the gradient mask
                                    letterSpacing:
                                        2.0, // Spaced letters look more like a premium logo
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              textAlign: TextAlign.center,
                              _usingEmail
                                  ? (_creatingAccount
                                        ? 'Create your account with email'
                                        : 'Sign in with your email')
                                  : 'Sign in or create an account to continue',
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
                            if (_usingEmail)
                              Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: _email,
                                      enabled: !isBusy,
                                      keyboardType: TextInputType.emailAddress,
                                      autofillHints: const [
                                        AutofillHints.email,
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                        prefixIcon: Icon(Icons.email_outlined),
                                      ),
                                      validator: (value) {
                                        final email = value?.trim() ?? '';
                                        if (!RegExp(
                                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                        ).hasMatch(email)) {
                                          return 'Enter a valid email address';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _password,
                                      enabled: !isBusy,
                                      obscureText: !_showPassword,
                                      autofillHints: [
                                        _creatingAccount
                                            ? AutofillHints.newPassword
                                            : AutofillHints.password,
                                      ],
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                        ),
                                        suffixIcon: IconButton(
                                          tooltip: _showPassword
                                              ? 'Hide password'
                                              : 'Show password',
                                          onPressed: isBusy
                                              ? null
                                              : () => setState(
                                                  () => _showPassword =
                                                      !_showPassword,
                                                ),
                                          icon: Icon(
                                            _showPassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Enter your password';
                                        }
                                        if (_creatingAccount &&
                                            value.length < 6) {
                                          return 'Use at least 6 characters';
                                        }
                                        return null;
                                      },
                                    ),
                                    if (_creatingAccount) ...[
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _confirmPassword,
                                        enabled: !isBusy,
                                        obscureText: !_showPassword,
                                        autofillHints: const [
                                          AutofillHints.newPassword,
                                        ],
                                        decoration: const InputDecoration(
                                          labelText: 'Confirm password',
                                          prefixIcon: Icon(Icons.lock_outline),
                                        ),
                                        validator: (value) =>
                                            value != _password.text
                                            ? 'Passwords do not match'
                                            : null,
                                      ),
                                    ],
                                    const SizedBox(height: 20),
                                    FilledButton.icon(
                                      onPressed: isBusy ? null : _submitEmail,
                                      icon: Icon(
                                        _creatingAccount
                                            ? Icons.person_add_outlined
                                            : Icons.login,
                                      ),
                                      label: Text(
                                        isBusy
                                            ? 'Please wait...'
                                            : (_creatingAccount
                                                  ? 'Create account'
                                                  : 'Sign in'),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: isBusy
                                          ? null
                                          : () => _switchMode(
                                              email: true,
                                              create: !_creatingAccount,
                                            ),
                                      child: Text(
                                        _creatingAccount
                                            ? 'Already have an account? Sign in'
                                            : 'Need an account? Create account',
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: isBusy
                                          ? null
                                          : () => _switchMode(email: false),
                                      child: const Text(
                                        'Other sign-in options',
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              FilledButton.icon(
                                onPressed: isBusy ? null : _signInWithGoogle,
                                icon: const Icon(Icons.login),
                                label: const Text('Continue with Google'),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: isBusy
                                    ? null
                                    : () => _switchMode(
                                        email: true,
                                        create: true,
                                      ),
                                icon: const Icon(Icons.person_add_outlined),
                                label: const Text('Create account with email'),
                              ),
                              TextButton(
                                onPressed: isBusy
                                    ? null
                                    : () => _switchMode(email: true),
                                child: const Text('Sign in with email'),
                              ),
                            ],
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
