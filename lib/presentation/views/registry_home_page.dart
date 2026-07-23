import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/models/booking.dart';
import '../../domain/models/expense.dart';
import '../theme/app_colors.dart';
import '../viewmodels/auth_view_model.dart';
import '../viewmodels/registry_view_model.dart';

part 'Dashboard_screen.dart';
part 'Bookings_screen.dart';
part 'expenses_screen.dart';
part 'reports_screen.dart';

// -------------------------------
// Presentation Layer
// -------------------------------

class RegistryHomePage extends StatefulWidget {
  const RegistryHomePage({
    super.key,
    required this.guestHouseName,
    required this.onGuestHouseNameChanged,
    required this.registryViewModel,
    required this.authViewModel,
  });

  final String guestHouseName;
  final ValueChanged<String> onGuestHouseNameChanged;
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
              decoration: const InputDecoration(labelText: 'Guest house name'),
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
    widget.onGuestHouseNameChanged(newName);

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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _registryViewModel,
      builder: (context, _) {
        final pages = [
          DashboardScreen(controller: _registryViewModel),
          BookingsScreen(
            controller: _registryViewModel,
            guestHouseName: widget.guestHouseName,
          ),
          ExpensesScreen(controller: _registryViewModel),
          ReportsScreen(controller: _registryViewModel),
        ];

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Color.fromARGB(255, 5, 47, 54),
            foregroundColor: AppColors.dashboardText,
            title: Text(widget.guestHouseName),
            titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.dashboardText,
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
                        backgroundColor: AppColors.dashboardAccent.withValues(
                          alpha: 0.2,
                        ),
                        child: Text(
                          avatarText,
                          style: const TextStyle(
                            color: AppColors.dashboardText,
                          ),
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
              backgroundColor: Color.fromARGB(255, 5, 47, 54),
              indicatorColor: AppColors.dashboardAccent.withValues(alpha: 0.22),
              labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((
                states,
              ) {
                final isSelected = states.contains(WidgetState.selected);
                return TextStyle(
                  color: isSelected
                      ? AppColors.dashboardAccent
                      : AppColors.dashboardText.withValues(alpha: 0.85),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((
                states,
              ) {
                final isSelected = states.contains(WidgetState.selected);
                return IconThemeData(
                  color: isSelected
                      ? AppColors.dashboardAccent
                      : AppColors.dashboardText.withValues(alpha: 0.85),
                  size: 20,
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bed_outlined),
                  selectedIcon: Icon(Icons.bed),
                  label: 'Bookings',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Expenses',
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
// Shared Widgets
// -------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.dashboardAccent.withValues(alpha: 0.2),
          child: Icon(icon, color: AppColors.dashboardAccent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.dashboardText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.dashboardText.withValues(alpha: 0.8),
                ),
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

class _BookingMetaRow extends StatelessWidget {
  const _BookingMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final valueStyle = emphasize
        ? Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          )
        : Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);

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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.dashboardCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.inbox_outlined,
              color: AppColors.dashboardText.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.dashboardText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

ThemeData _nightTabTheme(BuildContext context) {
  final base = Theme.of(context);

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.dashboardAccent,
      secondary: AppColors.dashboardAccent,
      onPrimary: AppColors.dashboardCanvas,
      surface: AppColors.dashboardCard,
      onSurface: AppColors.dashboardText,
    ),
    cardTheme: base.cardTheme.copyWith(color: AppColors.dashboardCard),
    iconTheme: base.iconTheme.copyWith(color: AppColors.dashboardText),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.dashboardText,
      displayColor: AppColors.dashboardText,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white54),
      prefixIconColor: Colors.white70,
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.dashboardAccent),
      ),
    ),
    dropdownMenuTheme: base.dropdownMenuTheme.copyWith(
      textStyle: const TextStyle(color: AppColors.dashboardText),
    ),
  );
}

class _FinancialSummaryBar extends StatelessWidget {
  const _FinancialSummaryBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    this.textColor = Colors.black,
  });

  final String label;
  final double value;
  final double max;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final ratio = (value / max).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: textColor)),
            Text(
              _currency(value),
              style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 12,
            value: ratio,
            color: color,
            backgroundColor: color.withValues(alpha: 0.16),
          ),
        ),
      ],
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  const _DashboardMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.cardColor,
    required this.textColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color cardColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: cardColor,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSectionTitle extends StatelessWidget {
  const _DashboardSectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.dashboardAccent.withValues(alpha: 0.2),
          child: Icon(icon, color: AppColors.dashboardAccent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.dashboardText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.dashboardText.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.16),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.dashboardText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
