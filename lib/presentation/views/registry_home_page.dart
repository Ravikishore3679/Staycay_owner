import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/repositories/account_profile_repository.dart';
import '../../domain/models/booking.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/monthly_report.dart';
import '../theme/app_colors.dart';
import '../viewmodels/auth_view_model.dart';
import '../viewmodels/registry_view_model.dart';
import 'account_profile_screen.dart';

part 'Dashboard_screen.dart';
part 'Bookings_screen.dart';
part 'expenses_screen.dart';
part 'reports_screen.dart';
part 'manage_screen.dart';

// -----------------------------
// Presentation Layer

class RegistryHomePage extends StatefulWidget {
  const RegistryHomePage({
    super.key,
    required this.guestHouseName,
    required this.guestHouseAddress,
    required this.guestHousePhotoBytes,
    required this.registryViewModel,
    required this.authViewModel,
    required this.accountProfileRepository,
  });

  final String guestHouseName;
  final String guestHouseAddress;
  final Uint8List? guestHousePhotoBytes;
  final RegistryViewModel registryViewModel;
  final AuthViewModel authViewModel;
  final AccountProfileRepository accountProfileRepository;

  @override
  State<RegistryHomePage> createState() => _RegistryHomePageState();
}

class _RegistryHomePageState extends State<RegistryHomePage> {
  late final RegistryViewModel _registryViewModel;
  late final AuthViewModel _authViewModel;
  int _index = 0;
  int _manageVisit = 0;
  Future<void> _signInWithGoogle() async {
    try {
      await _authViewModel.signInWithGoogle();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Signed in with Google')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google sign-in failed: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    _registryViewModel = widget.registryViewModel;
    _authViewModel = widget.authViewModel;
  }

  void _openBookingForDate(DateTime date) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Add booking')),
          body: SafeArea(
            child: BookingsScreen(
              controller: _registryViewModel,
              guestHouseName: widget.guestHouseName,
              guestHouseAddress: widget.guestHouseAddress,
              guestHousePhotoBytes: widget.guestHousePhotoBytes,
              initialCheckIn: date,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _registryViewModel,
      builder: (context, _) {
        final pages = [
          DashboardScreen(
            controller: _registryViewModel,
            onAddBookingForDate: _openBookingForDate,
            guestHouseName: widget.guestHouseName,
            guestHouseAddress: widget.guestHouseAddress,
            guestHousePhotoBytes: widget.guestHousePhotoBytes,
          ),
          ManageScreen(
            key: ValueKey('manage-$_manageVisit'),
            controller: _registryViewModel,
            guestHouseName: widget.guestHouseName,
            guestHouseAddress: widget.guestHouseAddress,
            guestHousePhotoBytes: widget.guestHousePhotoBytes,
          ),
          ReportsScreen(controller: _registryViewModel),
        ];

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.textStrong,
            toolbarHeight: 68,
            titleSpacing: 12,
            title: _GuestHouseHeaderTitle(
              guestHouseName: widget.guestHouseName,
              guestHouseAddress: widget.guestHouseAddress,
            ),
            titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textStrong,
              fontWeight: FontWeight.w700,
            ),
            centerTitle: false,
            surfaceTintColor: Colors.transparent,
            actions: [
              StreamBuilder<User?>(
                stream: _authViewModel.authStateChanges(),
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  if (user == null) {
                    return TextButton.icon(
                      onPressed: _signInWithGoogle,
                      icon: const Icon(Icons.login, size: 18),
                      label: const Text('Sign in'),
                    );
                  }

                  return _AccountAvatarButton(
                    user: user,
                    repository: widget.accountProfileRepository,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AccountProfileScreen(
                          user: user,
                          repository: widget.accountProfileRepository,
                          authViewModel: _authViewModel,
                          initialGuestHouseName:
                              widget.guestHouseName == 'Guest House Registry'
                              ? ''
                              : widget.guestHouseName,
                          initialGuestHouseAddress: widget.guestHouseAddress,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            child:
                _registryViewModel.isLoading &&
                    _registryViewModel.bookings.isEmpty &&
                    _registryViewModel.expenses.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      if (_registryViewModel.errorMessage != null)
                        Material(
                          color: Theme.of(
                            context,
                          ).colorScheme.errorContainer.withValues(alpha: 0.4),
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.sync_problem,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            title: Text(
                              _registryViewModel.errorMessage!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            trailing: TextButton(
                              onPressed: _registryViewModel.loadData,
                              child: const Text('Retry'),
                            ),
                          ),
                        ),
                      Expanded(
                        child: IndexedStack(index: _index, children: pages),
                      ),
                    ],
                  ),
          ),
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.white,
              indicatorColor: AppColors.revenueSoft,
              elevation: 8,
              labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((
                states,
              ) {
                final isSelected = states.contains(WidgetState.selected);
                return TextStyle(
                  color: isSelected
                      ? AppColors.brandPrimary
                      : const Color(0xFF64748B),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((
                states,
              ) {
                final isSelected = states.contains(WidgetState.selected);
                return IconThemeData(
                  color: isSelected
                      ? AppColors.brandPrimary
                      : const Color(0xFF64748B),
                  size: 20,
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.add_circle_outline),
                  selectedIcon: Icon(Icons.add_circle),
                  label: 'Manage',
                ),
                NavigationDestination(
                  icon: Icon(Icons.analytics_outlined),
                  selectedIcon: Icon(Icons.analytics),
                  label: 'Reports',
                ),
              ],
              onDestinationSelected: (newIndex) {
                setState(() {
                  if (newIndex == 1) _manageVisit++;
                  _index = newIndex;
                });
              },
            ),
          ),
        );
      },
    );
  }
}
// -------------------------------

// -------------------------------
// Shared Widgets
// -------------------------------

class _AccountAvatarButton extends StatefulWidget {
  const _AccountAvatarButton({
    required this.user,
    required this.repository,
    required this.onPressed,
  });

  final User user;
  final AccountProfileRepository repository;
  final VoidCallback onPressed;

  @override
  State<_AccountAvatarButton> createState() => _AccountAvatarButtonState();
}

class _AccountAvatarButtonState extends State<_AccountAvatarButton> {
  late Stream<AccountProfile?> _profileStream;

  @override
  void initState() {
    super.initState();
    _profileStream = widget.repository.watchProfile(widget.user.uid);
  }

  @override
  void didUpdateWidget(_AccountAvatarButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid ||
        oldWidget.repository != widget.repository) {
      _profileStream = widget.repository.watchProfile(widget.user.uid);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AccountProfile?>(
    stream: _profileStream,
    builder: (context, snapshot) {
      final profile = snapshot.data;
      final name =
          profile?.name ?? widget.user.displayName ?? widget.user.email ?? '';
      return IconButton(
        tooltip: 'My profile',
        onPressed: widget.onPressed,
        icon: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.revenueSoft,
          foregroundImage: profile?.photoBytes == null
              ? null
              : MemoryImage(profile!.photoBytes!),
          child: profile?.photoBytes == null
              ? name.isEmpty
                    ? const Icon(
                        Icons.person_outline,
                        color: AppColors.revenueDark,
                      )
                    : Text(
                        name.characters.first.toUpperCase(),
                        style: const TextStyle(color: AppColors.revenueDark),
                      )
              : null,
        ),
      );
    },
  );
}

class _GuestHouseHeaderTitle extends StatelessWidget {
  const _GuestHouseHeaderTitle({
    required this.guestHouseName,
    required this.guestHouseAddress,
  });

  final String guestHouseName;
  final String guestHouseAddress;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          guestHouseName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.brandPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        if (guestHouseAddress.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            guestHouseAddress,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF475569)),
          ),
        ],
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.date_range_outlined),
        ),
        child: Text(value == null ? 'Select date' : _formatDate(value!)),
      ),
    );
  }
}

class _ReadOnlyAmountCard extends StatelessWidget {
  const _ReadOnlyAmountCard({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            _currency(amount),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: amount >= 0
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final valueStyle = emphasize
        ? Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor ?? Theme.of(context).colorScheme.primary,
          )
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: valueStyle)),
        ],
      ),
    );
  }
}

ThemeData _lightTabTheme(BuildContext context) {
  final base = Theme.of(context);

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.brandPrimary,
      secondary: AppColors.revenueDark,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: AppColors.textStrong,
      onSurfaceVariant: const Color(0xFF64748B),
    ),
    scaffoldBackgroundColor: AppColors.appBackground,
    cardTheme: base.cardTheme.copyWith(color: Colors.white),
    iconTheme: base.iconTheme.copyWith(color: AppColors.brandPrimary),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textStrong,
      displayColor: AppColors.textStrong,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      labelStyle: const TextStyle(color: Color(0xFF475569)),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      prefixIconColor: const Color(0xFF64748B),
      suffixIconColor: const Color(0xFF64748B),
    ),
    dropdownMenuTheme: base.dropdownMenuTheme.copyWith(
      textStyle: const TextStyle(color: AppColors.textStrong),
    ),
  );
}

// -------------------------------
// Utilities
// -------------------------------

String _currency(double amount) => 'Rs ${amount.toStringAsFixed(2)}';

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')} ${_monthName(date.month)} ${date.year}';

String _monthName(int month) {
  const names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  if (month < 1 || month > 12) return 'Unknown';
  return names[month - 1];
}
