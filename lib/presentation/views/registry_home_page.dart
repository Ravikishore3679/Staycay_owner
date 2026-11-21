import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/models/booking.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/monthly_report.dart';
import '../theme/app_colors.dart';
import '../viewmodels/auth_view_model.dart';
import '../viewmodels/registry_view_model.dart';

part 'Dashboard_screen.dart';
part 'Bookings_screen.dart';
part 'expenses_screen.dart';
part 'reports_screen.dart';
part 'add_screen.dart';

// -----------------------------
// Presentation Layer

class RegistryHomePage extends StatefulWidget {
  const RegistryHomePage({
    super.key,
    required this.guestHouseName,
    required this.guestHouseAddress,
    required this.guestHousePhotoBytes,
    required this.onGuestHouseNameChanged,
    required this.registryViewModel,
    required this.authViewModel,
  });

  final String guestHouseName;
  final String guestHouseAddress;
  final Uint8List? guestHousePhotoBytes;
  final Future<void> Function(String value) onGuestHouseNameChanged;
  final RegistryViewModel registryViewModel;
  final AuthViewModel authViewModel;

  @override
  State<RegistryHomePage> createState() => _RegistryHomePageState();
}

class _RegistryHomePageState extends State<RegistryHomePage> {
  late final RegistryViewModel _registryViewModel;
  late final AuthViewModel _authViewModel;
  int _index = 0;
  Future<void> _editGuestHouseName() async {
    final controller = TextEditingController(text: widget.guestHouseName);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final formKey = GlobalKey<FormState>();

        return AlertDialog(
          title: const Text('Edit Guest House Name'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: Color(0xFF0A1D21)),
              decoration: const InputDecoration(
                labelText: 'Guest house name',
                labelStyle: TextStyle(color: Color(0xFF0A1D21)),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Guest house name is required';
                if (text.length < 3) return 'Enter at least 3 characters';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (newName == null || newName == widget.guestHouseName) return;

    try {
      await widget.onGuestHouseNameChanged(newName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update guest house name: $e')),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Guest house name updated to "$newName"')),
    );
  }

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

  Future<void> _signOutToAnonymous() async {
    try {
      await _authViewModel.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Signed out')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign-out failed: $e')));
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
          ),
          AddScreen(
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
              guestHousePhotoBytes: widget.guestHousePhotoBytes,
            ),
            titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textStrong,
              fontWeight: FontWeight.w700,
            ),
            centerTitle: false,
            surfaceTintColor: Colors.transparent,
            actions: [
              IconButton(
                onPressed: _editGuestHouseName,
                tooltip: 'Edit guest house name',

                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
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

                  final displayName = user.isAnonymous
                      ? 'Guest'
                      : (user.displayName ?? user.email ?? 'Account');
                  final avatarText = displayName.isEmpty
                      ? 'A'
                      : displayName[0].toUpperCase();

                  return PopupMenuButton<String>(
                    color: Colors.white,
                    tooltip: 'Account',
                    onSelected: (value) {
                      if (value == 'signin') {
                        _signInWithGoogle();
                      } else if (value == 'signout') {
                        _signOutToAnonymous();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        enabled: false,
                        value: 'label',
                        child: Text(displayName),
                      ),
                      if (user.isAnonymous)
                        const PopupMenuItem<String>(
                          value: 'signin',
                          child: Text('Sign in with Google'),
                        ),
                      const PopupMenuItem<String>(
                        value: 'signout',
                        child: Text('Sign out'),
                      ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.revenueSoft,
                        child: Text(
                          avatarText,
                          style: const TextStyle(color: AppColors.revenueDark),
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
                  label: 'Add',
                ),
                NavigationDestination(
                  icon: Icon(Icons.analytics_outlined),
                  selectedIcon: Icon(Icons.analytics),
                  label: 'Reports',
                ),
              ],
              onDestinationSelected: (newIndex) {
                setState(() {
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

class _GuestHouseHeaderTitle extends StatelessWidget {
  const _GuestHouseHeaderTitle({
    required this.guestHouseName,
    required this.guestHouseAddress,
    required this.guestHousePhotoBytes,
  });

  final String guestHouseName;
  final String guestHouseAddress;
  final Uint8List? guestHousePhotoBytes;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.revenueSoft,
          backgroundImage: guestHousePhotoBytes != null
              ? MemoryImage(guestHousePhotoBytes!)
              : null,
          child: guestHousePhotoBytes == null
              ? const Icon(
                  Icons.home_work_outlined,
                  color: AppColors.brandPrimary,
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                guestHouseName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
          ),
        ),
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
        : Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: valueColor);

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
