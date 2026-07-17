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
              decoration: const InputDecoration(
                labelText: 'Guest house name',
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed in with Google')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
    }
  }

  Future<void> _signOutToAnonymous() async {
    try {
      await _authViewModel.signOutToAnonymous();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Switched to anonymous session')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-out failed: $e')),
      );
    }
  }
  @override
  void initState() {
    super.initState();
    _registryViewModel = widget.registryViewModel;
    _authViewModel = widget.authViewModel;
    _authViewModel.startListening(onUserChanged: (_) {
      _registryViewModel.loadData();
    });
  }

  @override
  void dispose() {
    _authViewModel.dispose();
    _registryViewModel.dispose();
    super.dispose();
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
            title: Text(widget.guestHouseName),
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
                    final avatarText =
                      displayName.isEmpty ? 'A' : displayName[0].toUpperCase();

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
                        child: Text(avatarText),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            child: _registryViewModel.isLoading &&
                    _registryViewModel.bookings.isEmpty &&
                    _registryViewModel.expenses.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      if (_registryViewModel.errorMessage != null)
                        Material(
                          color: Theme.of(context)
                              .colorScheme
                              .errorContainer
                              .withValues(alpha: 0.4),
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
                        child: IndexedStack(
                          index: _index,
                          children: pages,
                        ),
                      ),
                    ],
                  ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined, size: 20),
                selectedIcon: Icon(Icons.dashboard, size: 20),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.bed_outlined, size: 20),
                selectedIcon: Icon(Icons.bed, size: 20),
                label: 'Bookings',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined, size: 20),
                selectedIcon: Icon(Icons.receipt_long, size: 20),
                label: 'Expenses',
              ),
              NavigationDestination(
                icon: Icon(Icons.analytics_outlined, size: 20),
                selectedIcon: Icon(Icons.analytics, size: 20),
                label: 'Reports',
              ),
            ],
            onDestinationSelected: (newIndex) {
              setState(() {
                _index = newIndex;
              });
            },
          ),
        );
      },
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.controller});

  final RegistryViewModel controller;

  @override
  Widget build(BuildContext context) {
    final upcoming = controller.topUpcomingBookings;
    final revenue = controller.totalRevenue;
    final expense = controller.totalExpenditure;
    final net = revenue - expense;
    final progressMax = math.max(revenue, expense) <= 0 ? 1.0 : math.max(revenue, expense);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(
          icon: Icons.insights,
          title: 'Revenue vs Expenditure',
          subtitle: 'Overall financial snapshot',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DashboardMetricCard(
                label: 'Revenue',
                value: _currency(revenue),
                icon: Icons.trending_up,
                color: AppColors.revenue,
                lightColor: AppColors.revenueSoft,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DashboardMetricCard(
                label: 'Expenditure',
                value: _currency(expense),
                icon: Icons.trending_down,
                color: AppColors.expense,
                lightColor: AppColors.expenseSoft,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FinancialSummaryBar(
                  label: 'Revenue',
                  value: revenue,
                  max: progressMax,
                  color: AppColors.revenueBar,
                ),
                const SizedBox(height: 12),
                _FinancialSummaryBar(
                  label: 'Expenditure',
                  value: expense,
                  max: progressMax,
                  color: AppColors.expenseBar,
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: net >= 0
                          ? const [AppColors.netPositiveStart, AppColors.netPositiveEnd]
                          : const [AppColors.netNegativeStart, AppColors.netNegativeEnd],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        net >= 0 ? Icons.savings_outlined : Icons.warning_amber_rounded,
                        color: net >= 0 ? AppColors.revenue : AppColors.expense,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Net: ${_currency(net)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              color: net >= 0 ? AppColors.revenueDark : AppColors.expenseDark,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _SectionTitle(
          icon: Icons.event_available,
          title: 'Top 3 Upcoming Bookings',
          subtitle: 'Nearest check-ins first',
        ),
        const SizedBox(height: 12),
        if (upcoming.isEmpty)
          const _EmptyCard(message: 'No upcoming bookings yet.')
        else
          ...upcoming.map(
            (booking) => Card(
              color: AppColors.upcomingCard,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.upcomingAvatar,
                  child: Text('${booking.guests}'),
                ),
                title: Text(booking.name),
                subtitle: Text(
                  '${_formatDate(booking.checkIn)}  ->  ${_formatDate(booking.checkOut)}',
                ),
                trailing: Text(
                  _currency(booking.totalAmount),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({
    super.key,
    required this.controller,
    required this.guestHouseName,
  });

  final RegistryViewModel controller;
  final String guestHouseName;

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  static const List<String> _houseRules = [
    'Please carry a valid government ID during the stay.',
    'Check-out extensions are subject to room availability.',
    'Any damage to property will be chargeable to the guest.',
    'Loud music and disturbance are not allowed after 11:00 PM.',
    'Outstanding balance must be cleared before check-in.',
    'please maintain cleanliness and hygiene in the rooms and common areas.',
    'Pets are allowed in the guest house premises only upon prior notice.',
    'Smoking is strictly prohibited inside the rooms and common areas.',
    'Guests are responsible for their personal belongings; the guest house is not liable for any loss.',
    'Swimming pool disipline: Children must be supervised by an adult at all times. No diving or running around the pool area.',
    'Penality for vomiting in the rooms will be 1000.',
  ];

  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();
  final _guestsCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _advanceCtrl = TextEditingController();

  DateTime? _checkIn;
  DateTime? _checkOut;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _aadhaarCtrl.dispose();
    _guestsCtrl.dispose();
    _totalCtrl.dispose();
    _advanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isCheckIn}) async {
    final now = DateTime.now();
    final initialDate = isCheckIn
        ? (_checkIn ?? now)
        : (_checkOut ?? _checkIn ?? now.add(const Duration(days: 1)));

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (selected == null) return;

    setState(() {
      if (isCheckIn) {
        _checkIn = selected;
        if (_checkOut != null && !_checkOut!.isAfter(_checkIn!)) {
          _checkOut = null;
        }
      } else {
        _checkOut = selected;
      }
    });
  }

  void _clearForm() {
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _aadhaarCtrl.clear();
    _guestsCtrl.clear();
    _totalCtrl.clear();
    _advanceCtrl.clear();
    setState(() {
      _checkIn = null;
      _checkOut = null;
    });
  }

  double _toAmount(String value) => double.tryParse(value.trim()) ?? 0.0;

  Future<Uint8List> _buildBookingReceiptPdf(Booking booking) async {
    final pdf = pw.Document();

    pw.Widget detailRow(String label, String value, {bool emphasize = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 110,
              child: pw.Text(
                '$label:',
                style: pw.TextStyle(color: PdfColors.blueGrey700),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  fontWeight:
                      emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.teal50,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                        widget.guestHouseName,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Booking Acknowledgement Receipt'),
                    pw.Text('Receipt ID: ${booking.id}'),
                    pw.Text('Issued On: ${_formatDate(DateTime.now())}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),
              detailRow('Guest Name', booking.name),
              detailRow('Phone', booking.phone),
              detailRow('Aadhaar', booking.aadhaar),
              detailRow('Check-in', _formatDate(booking.checkIn)),
              detailRow('Check-out', _formatDate(booking.checkOut)),
              detailRow('Guests', booking.guests.toString()),
              detailRow('Total Amount', _currency(booking.totalAmount)),
              detailRow('Advance Paid', _currency(booking.advancePaid)),
              detailRow(
                'Remaining Amount',
                _currency(booking.remainingAmount),
                emphasize: true,
              ),
              pw.SizedBox(height: 18),
              pw.Text(
                'Stay Rules',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              ..._houseRules.map(
                (rule) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('- '),
                      pw.Expanded(child: pw.Text(rule)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _downloadBookingReceiptPdf(Booking booking) async {
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      final bytes = await _buildBookingReceiptPdf(booking);
      final safeName = booking.name
          .trim()
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      final fileName =
          'booking_receipt_${safeName.isEmpty ? 'guest' : safeName}_${booking.id}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate receipt PDF: $e')),
      );
    }
  }

  Future<void> _showBookingReceipt(Booking booking) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Booking Acknowledgement'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          widget.guestHouseName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text('Receipt ID: ${booking.id}'),
                      Text('Issued On: ${_formatDate(DateTime.now())}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _ReceiptRow(label: 'Guest Name', value: booking.name),
                _ReceiptRow(label: 'Phone', value: booking.phone),
                _ReceiptRow(label: 'Aadhaar', value: booking.aadhaar),
                _ReceiptRow(label: 'Check-in', value: _formatDate(booking.checkIn)),
                _ReceiptRow(
                  label: 'Check-out',
                  value: _formatDate(booking.checkOut),
                ),
                _ReceiptRow(label: 'Guests', value: booking.guests.toString()),
                _ReceiptRow(
                  label: 'Total Amount',
                  value: _currency(booking.totalAmount),
                ),
                _ReceiptRow(
                  label: 'Advance Paid',
                  value: _currency(booking.advancePaid),
                ),
                _ReceiptRow(
                  label: 'Remaining Amount',
                  value: _currency(booking.remainingAmount),
                  emphasize: true,
                ),
                const SizedBox(height: 16),
                Text(
                  'Stay Rules',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                ..._houseRules.map(
                  (rule) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(rule)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              if (!mounted) return;
              await _downloadBookingReceiptPdf(booking);
            },
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Download PDF'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _editBooking(Booking booking) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: booking.name);
    final phoneCtrl = TextEditingController(text: booking.phone);
    final aadhaarCtrl = TextEditingController(text: booking.aadhaar);
    final guestsCtrl = TextEditingController(text: booking.guests.toString());
    final totalCtrl = TextEditingController(
      text: booking.totalAmount.toStringAsFixed(2),
    );
    final advanceCtrl = TextEditingController(
      text: booking.advancePaid.toStringAsFixed(2),
    );
    var checkIn = booking.checkIn;
    var checkOut = booking.checkOut;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogBuilderContext, setDialogState) {
            final total = _toAmount(totalCtrl.text);
            final advance = _toAmount(advanceCtrl.text);
            final remaining = total - advance;

            Future<void> pickDate({required bool isCheckIn}) async {
              final now = DateTime.now();
              final selected = await showDatePicker(
                context: dialogContext,
                initialDate: isCheckIn ? checkIn : checkOut,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 5),
              );

              if (selected == null) return;
              setDialogState(() {
                if (isCheckIn) {
                  checkIn = selected;
                  if (!checkOut.isAfter(checkIn)) {
                    checkOut = checkIn.add(const Duration(days: 1));
                  }
                } else {
                  checkOut = selected;
                }
              });
            }

            return AlertDialog(
              title: const Text('Edit Booking'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return 'Name is required';
                          if (v.length < 3) {
                            return 'Enter at least 3 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: const InputDecoration(labelText: 'Phone'),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return 'Phone number is required';
                          if (v.length != 10) return 'Phone must be 10 digits';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: aadhaarCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                        ],
                        decoration:
                            const InputDecoration(labelText: 'Aadhaar'),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return 'Aadhaar is required';
                          if (v.length != 12) {
                            return 'Aadhaar must be 12 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _DateField(
                              label: 'Check-in',
                              value: checkIn,
                              onTap: () => pickDate(isCheckIn: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DateField(
                              label: 'Check-out',
                              value: checkOut,
                              onTap: () => pickDate(isCheckIn: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: guestsCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        decoration:
                            const InputDecoration(labelText: 'No. of Guests'),
                        validator: (value) {
                          final v = int.tryParse(value?.trim() ?? '');
                          if (v == null) return 'Guests count is required';
                          if (v <= 0) return 'Guests must be at least 1';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: totalCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Total Amount'),
                        validator: (value) {
                          final v = double.tryParse(value?.trim() ?? '');
                          if (v == null) return 'Total amount is required';
                          if (v <= 0) return 'Must be greater than 0';
                          return null;
                        },
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: advanceCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Advance Paid'),
                        validator: (value) {
                          final a = double.tryParse(value?.trim() ?? '');
                          final t = double.tryParse(totalCtrl.text.trim());
                          if (a == null) return 'Advance amount is required';
                          if (a < 0) return 'Advance cannot be negative';
                          if (t != null && a > t) {
                            return 'Advance cannot exceed total';
                          }
                          return null;
                        },
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Remaining: ${_currency(remaining)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    if (!checkOut.isAfter(checkIn)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Check-out must be after check-in date'),
                        ),
                      );
                      return;
                    }

                    try {
                      final messenger = ScaffoldMessenger.of(context);
                      await widget.controller.updateBooking(
                        Booking(
                          id: booking.id,
                          name: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          aadhaar: aadhaarCtrl.text.trim(),
                          checkIn: checkIn,
                          checkOut: checkOut,
                          guests: int.parse(guestsCtrl.text.trim()),
                          totalAmount: _toAmount(totalCtrl.text),
                          advancePaid: _toAmount(advanceCtrl.text),
                        ),
                      );

                      if (!dialogContext.mounted || !mounted) return;
                      Navigator.of(dialogContext).pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Booking updated successfully'),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update booking: $e')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    phoneCtrl.dispose();
    aadhaarCtrl.dispose();
    guestsCtrl.dispose();
    totalCtrl.dispose();
    advanceCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookings = widget.controller.bookings;
    final total = _toAmount(_totalCtrl.text);
    final advance = _toAmount(_advanceCtrl.text);
    final remaining = total - advance;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(
          icon: Icons.edit_note,
          title: 'New Booking Entry',
          subtitle: 'Add guest details with payment split',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'Guest full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return 'Name is required';
                      if (v.length < 3) return 'Enter at least 3 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      hintText: '10-digit mobile number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return 'Phone number is required';
                      if (v.length != 10) return 'Phone must be 10 digits';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _aadhaarCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Aadhaar',
                      hintText: '12-digit Aadhaar number',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return 'Aadhaar is required';
                      if (v.length != 12) return 'Aadhaar must be 12 digits';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DateField(
                          label: 'Check-in',
                          value: _checkIn,
                          onTap: () => _pickDate(isCheckIn: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateField(
                          label: 'Check-out',
                          value: _checkOut,
                          onTap: () => _pickDate(isCheckIn: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _guestsCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'No. of Guests',
                            prefixIcon: Icon(Icons.groups_2_outlined),
                          ),
                          validator: (value) {
                            final v = int.tryParse(value?.trim() ?? '');
                            if (v == null) return 'Guests count is required';
                            if (v <= 0) return 'Guests must be at least 1';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _totalCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Total Amount',
                            prefixText: 'Rs ',
                          ),
                          validator: (value) {
                            final v = double.tryParse(value?.trim() ?? '');
                            if (v == null) return 'Total amount is required';
                            if (v <= 0) return 'Must be greater than 0';
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _advanceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Advance Paid',
                            prefixText: 'Rs ',
                          ),
                          validator: (value) {
                            final a = double.tryParse(value?.trim() ?? '');
                            final t = double.tryParse(_totalCtrl.text.trim());
                            if (a == null) return 'Advance amount is required';
                            if (a < 0) return 'Advance cannot be negative';
                            if (t != null && a > t) {
                              return 'Advance cannot exceed total';
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ReadOnlyAmountCard(
                          label: 'Remaining Amount',
                          amount: remaining,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            if (!(_formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            if (_checkIn == null || _checkOut == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Please select both check-in and check-out dates'),
                                ),
                              );
                              return;
                            }
                            if (!_checkOut!.isAfter(_checkIn!)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Check-out must be after check-in date'),
                                ),
                              );
                              return;
                            }

                            final booking = Booking(
                              id: DateTime.now()
                                  .microsecondsSinceEpoch
                                  .toString(),
                              name: _nameCtrl.text.trim(),
                              phone: _phoneCtrl.text.trim(),
                              aadhaar: _aadhaarCtrl.text.trim(),
                              checkIn: _checkIn!,
                              checkOut: _checkOut!,
                              guests: int.parse(_guestsCtrl.text.trim()),
                              totalAmount: _toAmount(_totalCtrl.text),
                              advancePaid: _toAmount(_advanceCtrl.text),
                            );

                            try {
                              await widget.controller.addBooking(booking);
                              _clearForm();
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Booking added successfully'),
                                ),
                              );
                              try {
                                await _showBookingReceipt(booking);
                              } catch (e) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Booking saved, but receipt preview failed: $e',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Failed to add booking: $e'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.add_task, size: 18),
                          label: const Text('Add Booking'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _clearForm,
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _SectionTitle(
          icon: Icons.list_alt,
          title: 'Current & Past Bookings',
          subtitle: 'All booking records',
        ),
        const SizedBox(height: 12),
        if (bookings.isEmpty)
          const _EmptyCard(message: 'No bookings found.')
        else
          ...bookings.map(
            (booking) => Card(
              child: ExpansionTile(
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                childrenPadding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 14),
                leading: CircleAvatar(
                  backgroundColor: booking.isUpcoming
                      ? AppColors.upcomingIndicator
                      : AppColors.historyIndicator,
                  child: Icon(
                    booking.isUpcoming
                        ? Icons.event_available
                        : Icons.history,
                    color: booking.isUpcoming
                        ? AppColors.revenueBar
                        : AppColors.historyIcon,
                  ),
                ),
                title: Text(booking.name),
                subtitle: Text(
                  '${_formatDate(booking.checkIn)}  ->  ${_formatDate(booking.checkOut)}',
                ),
                trailing: Text(
                  _currency(booking.totalAmount),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                children: [
                  _BookingMetaRow(label: 'Phone', value: booking.phone),
                  _BookingMetaRow(label: 'Aadhaar', value: booking.aadhaar),
                  _BookingMetaRow(
                    label: 'Guests',
                    value: booking.guests.toString(),
                  ),
                  _BookingMetaRow(
                    label: 'Advance Paid',
                    value: _currency(booking.advancePaid),
                  ),
                  _BookingMetaRow(
                    label: 'Remaining',
                    value: _currency(booking.remainingAmount),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _editBooking(booking),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key, required this.controller});

  final RegistryViewModel controller;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _clearForm() {
    _titleCtrl.clear();
    _amountCtrl.clear();
    _descriptionCtrl.clear();
  }

  Future<void> _editExpense(Expense expense) async {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: expense.title);
    final amountCtrl = TextEditingController(
      text: expense.amount.toStringAsFixed(2),
    );
    final descriptionCtrl = TextEditingController(text: expense.description);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Expense'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Expenditure Title / Category',
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return 'Title or category is required';
                      if (v.length < 3) return 'Enter at least 3 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Amount'),
                    validator: (value) {
                      final v = double.tryParse(value?.trim() ?? '');
                      if (v == null) return 'Amount is required';
                      if (v <= 0) return 'Amount must be greater than 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: descriptionCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return 'Description is required';
                      if (v.length < 5) return 'Enter at least 5 characters';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                if (!(formKey.currentState?.validate() ?? false)) return;

                try {
                  await widget.controller.updateExpense(
                    Expense(
                      id: expense.id,
                      title: titleCtrl.text.trim(),
                      amount: double.parse(amountCtrl.text.trim()),
                      description: descriptionCtrl.text.trim(),
                      date: expense.date,
                    ),
                  );

                  if (!dialogContext.mounted || !mounted) return;
                  Navigator.of(dialogContext).pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Expense updated successfully')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to update expense: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    titleCtrl.dispose();
    amountCtrl.dispose();
    descriptionCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expenses = widget.controller.expenses;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(
          icon: Icons.add_card,
          title: 'Add Expense',
          subtitle: 'Track operational expenditures',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Expenditure Title / Category',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return 'Title or category is required';
                      if (v.length < 3) return 'Enter at least 3 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: 'Rs ',
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    validator: (value) {
                      final v = double.tryParse(value?.trim() ?? '');
                      if (v == null) return 'Amount is required';
                      if (v <= 0) return 'Amount must be greater than 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return 'Description is required';
                      if (v.length < 5) return 'Enter at least 5 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            if (!(_formKey.currentState?.validate() ?? false)) {
                              return;
                            }

                            try {
                              await widget.controller.addExpense(
                                Expense(
                                  id: DateTime.now()
                                      .microsecondsSinceEpoch
                                      .toString(),
                                  title: _titleCtrl.text.trim(),
                                  amount:
                                      double.parse(_amountCtrl.text.trim()),
                                  description: _descriptionCtrl.text.trim(),
                                  date: DateTime.now(),
                                ),
                              );

                              _clearForm();
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Expense added successfully'),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Failed to add expense: $e'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('Add Expense'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _clearForm,
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _SectionTitle(
          icon: Icons.history,
          title: 'Past Expenses',
          subtitle: 'Latest entries shown first',
        ),
        const SizedBox(height: 12),
        if (expenses.isEmpty)
          const _EmptyCard(message: 'No expenses found.')
        else
          ...expenses.map(
            (expense) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                  child: const Icon(Icons.receipt_long),
                ),
                title: Text(expense.title),
                subtitle: Text(
                  '${expense.description}\n${_formatDate(expense.date)}',
                ),
                isThreeLine: true,
                trailing: SizedBox(
                  width: 128,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          _currency(expense.amount),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: AppColors.textStrong,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 18),
                        tooltip: 'Expense actions',
                        onSelected: (value) {
                          if (value == 'edit') {
                            _editExpense(expense);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.controller});

  final RegistryViewModel controller;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
  }

  Future<void> _deleteBooking(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Booking'),
        content: Text(
          'Are you sure you want to delete the booking for ${booking.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.controller.deleteBooking(booking.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete booking: $e')),
      );
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text(
          'Are you sure you want to delete "${expense.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.controller.deleteExpense(expense.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete expense: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final report =
        widget.controller.getMonthlyReport(_selectedYear, _selectedMonth);
    final years = [for (int y = DateTime.now().year - 2; y <= DateTime.now().year + 2; y++) y];

    final monthBookings =
      widget.controller.bookingsForMonth(_selectedYear, _selectedMonth);
    final monthExpenses =
      widget.controller.expensesForMonth(_selectedYear, _selectedMonth);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(
          icon: Icons.filter_alt,
          title: 'Monthly Reports',
          subtitle: 'Filter by month and year',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _selectedMonth,
                    decoration: const InputDecoration(labelText: 'Month'),
                    items: [
                      for (int month = 1; month <= 12; month++)
                        DropdownMenuItem(
                          value: month,
                          child: Text(_monthName(month)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedMonth = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _selectedYear,
                    decoration: const InputDecoration(labelText: 'Year'),
                    items: years
                        .map(
                          (year) => DropdownMenuItem(
                            value: year,
                            child: Text(year.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedYear = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 260,
              child: _ReportCard(
                title: 'Total Revenue',
                value: _currency(report.revenue),
                color: AppColors.brandPrimary,
                icon: Icons.trending_up,
              ),
            ),
            SizedBox(
              width: 260,
              child: _ReportCard(
                title: 'Total Expenses',
                value: _currency(report.expenses),
                color: AppColors.expenseReport,
                icon: Icons.trending_down,
              ),
            ),
            SizedBox(
              width: 260,
              child: _ReportCard(
                title: 'Net Profit / Loss',
                value: _currency(report.net),
                color:
                  report.net >= 0 ? AppColors.revenue : AppColors.expenseReport,
                icon: report.net >= 0
                    ? Icons.account_balance_wallet_outlined
                    : Icons.warning_amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (monthBookings.isNotEmpty) ...
          [
            _SectionTitle(
              icon: Icons.hotel,
              title: 'Bookings',
              subtitle: 'Manage bookings for ${_monthName(_selectedMonth)} $_selectedYear',
            ),
            const SizedBox(height: 12),
            ...monthBookings.map((booking) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                booking.phone,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _currency(booking.totalAmount),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_formatDate(booking.checkIn)} to ${_formatDate(booking.checkOut)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        IconButton(
                          onPressed: () => _deleteBooking(booking),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: 'Delete booking',
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 24),
          ]
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No bookings for ${_monthName(_selectedMonth)} $_selectedYear',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        if (monthExpenses.isNotEmpty) ...
          [
            _SectionTitle(
              icon: Icons.receipt_long,
              title: 'Expenses',
              subtitle: 'Manage expenses for ${_monthName(_selectedMonth)} $_selectedYear',
            ),
            const SizedBox(height: 12),
            ...monthExpenses.map((expense) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                expense.title,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                expense.description,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _currency(expense.amount),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDate(expense.date),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        IconButton(
                          onPressed: () => _deleteExpense(expense),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: 'Delete expense',
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
          ]
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No expenses for ${_monthName(_selectedMonth)} $_selectedYear',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
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
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
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
          Expanded(
            child: Text(
              value,
              style: valueStyle,
            ),
          ),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.inbox_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _FinancialSummaryBar extends StatelessWidget {
  const _FinancialSummaryBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  final String label;
  final double value;
  final double max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = (value / max).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              _currency(value),
              style: const TextStyle(fontWeight: FontWeight.w700),
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
    required this.lightColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color lightColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [lightColor, Colors.white],
        ),
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
                      color: color,
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
                  color: color,
                ),
          ),
        ],
      ),
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
                    style: Theme.of(context).textTheme.titleMedium,
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
