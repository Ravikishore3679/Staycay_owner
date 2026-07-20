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
  final _emailFormKey = GlobalKey<FormState>();
  final _smsFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _createAccount = false;

  AuthViewModel get _authViewModel => widget.authViewModel;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;

    try {
      if (_createAccount) {
        await _authViewModel.createAccountWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await _authViewModel.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } catch (_) {}
  }

  Future<void> _sendSmsCode() async {
    if (!(_smsFormKey.currentState?.validate() ?? false)) return;

    try {
      await _authViewModel.sendSmsCode(_phoneController.text.trim());
    } catch (_) {}
  }

  Future<void> _verifySmsCode() async {
    if (_otpController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the 6-digit code sent to your phone.'),
        ),
      );
      return;
    }

    try {
      await _authViewModel.verifySmsCode(_otpController.text.trim());
    } catch (_) {}
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
        final hasPendingPhoneVerification =
            _authViewModel.hasPendingPhoneVerification;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            body: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF7FBFF),
                    Color(0xFFE8F3FF),
                    Color(0xFFDDEBFF),
                  ],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                height: 56,
                                width: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.brandPrimary,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.lock_open_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Welcome back',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textStrong,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sign in with email, Google, or an SMS verification code.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.black54,
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
                              const SizedBox(height: 20),
                              const TabBar(
                                tabs: [
                                  Tab(text: 'Email'),
                                  Tab(text: 'SMS'),
                                ],
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: hasPendingPhoneVerification ? 340 : 280,
                                child: TabBarView(
                                  children: [
                                    _buildEmailTab(isBusy),
                                    _buildSmsTab(
                                      theme,
                                      isBusy,
                                      hasPendingPhoneVerification,
                                    ),
                                  ],
                                ),
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
          ),
        );
      },
    );
  }

  Widget _buildEmailTab(bool isBusy) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Email is required';
              if (!text.contains('@')) return 'Enter a valid email address';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.password_rounded),
            ),
            validator: (value) {
              final text = value ?? '';
              if (text.isEmpty) return 'Password is required';
              if (text.length < 6) return 'Use at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: isBusy ? null : _submitEmail,
            child: Text(_createAccount ? 'Create account' : 'Sign in'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: isBusy
                ? null
                : () {
                    setState(() {
                      _createAccount = !_createAccount;
                    });
                  },
            child: Text(
              _createAccount
                  ? 'Already have an account? Sign in'
                  : 'Need an account? Create one',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmsTab(
    ThemeData theme,
    bool isBusy,
    bool hasPendingPhoneVerification,
  ) {
    return Form(
      key: _smsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            enabled: !hasPendingPhoneVerification,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '+15551234567',
              prefixIcon: Icon(Icons.phone_iphone_rounded),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Phone number is required';
              if (!text.startsWith('+') || text.length < 10) {
                return 'Use international format, for example +15551234567';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Text(
            hasPendingPhoneVerification
                ? 'Code sent to ${_authViewModel.pendingPhoneNumber}. Enter it below.'
                : 'We will send a one-time code to verify your number.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          if (hasPendingPhoneVerification) ...[
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Verification code',
                prefixIcon: Icon(Icons.sms_rounded),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: isBusy ? null : _verifySmsCode,
              child: const Text('Verify code'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: isBusy
                  ? null
                  : () {
                      _otpController.clear();
                      _authViewModel.resetPhoneVerification();
                    },
              child: const Text('Use a different number'),
            ),
          ] else ...[
            FilledButton(
              onPressed: isBusy ? null : _sendSmsCode,
              child: const Text('Send verification code'),
            ),
          ],
        ],
      ),
    );
  }
}
