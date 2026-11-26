part of 'registry_home_page.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
    required this.onAddBookingForDate,
    required this.guestHouseName,
    required this.guestHouseAddress,
    required this.guestHousePhotoBytes,
  });

  final RegistryViewModel controller;
  final ValueChanged<DateTime> onAddBookingForDate;
  final String guestHouseName;
  final String guestHouseAddress;
  final Uint8List? guestHousePhotoBytes;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  DateTime _visibleMonth = DateUtils.dateOnly(DateTime.now());
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnightRefresh();
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(midnight.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleMidnightRefresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _scheduleMidnightRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }

  void _changeMonth(int amount) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + amount,
        1,
      );
      _selectedDate = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    });
  }

  bool _isStayDate(Booking booking, DateTime date) {
    final day = DateUtils.dateOnly(date);
    final checkIn = DateUtils.dateOnly(booking.checkIn);
    final checkOut = DateUtils.dateOnly(booking.checkOut);
    return !booking.isCancelled &&
        !day.isBefore(checkIn) &&
        day.isBefore(checkOut);
  }

  void _showBookingDetails(Booking booking) {
    var currentBooking = booking;
    var saving = false;
    String? actionError;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.revenueSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_note_outlined,
                  color: AppColors.revenueDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Booking details',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BookingDetailHeading(
                  title: 'Guest & stay',
                  status: currentBooking.isCancelled ? 'Cancelled' : 'Active',
                  cancelled: currentBooking.isCancelled,
                ),
                const SizedBox(height: 12),
                _ReceiptRow(label: 'Guest name', value: currentBooking.name),
                _ReceiptRow(label: 'Phone', value: currentBooking.phone),
                _ReceiptRow(
                  label: 'Aadhaar',
                  value: currentBooking.aadhaar.isEmpty
                      ? 'Not provided'
                      : currentBooking.aadhaar,
                ),
                _ReceiptRow(
                  label: 'Check-in',
                  value: _formatDate(currentBooking.checkIn),
                ),
                _ReceiptRow(
                  label: 'Check-out',
                  value: _formatDate(currentBooking.checkOut),
                ),
                _ReceiptRow(label: 'Guests', value: '${currentBooking.guests}'),
                const SizedBox(height: 4),
                const Divider(height: 24),
                const _BookingDetailHeading(title: 'Payment summary'),
                const SizedBox(height: 12),
                _ReceiptRow(
                  label: 'Total amount',
                  value: _currency(currentBooking.totalAmount),
                ),
                _ReceiptRow(
                  label: 'Advance paid',
                  value: _currency(currentBooking.advancePaid),
                ),
                _ReceiptRow(
                  label: 'Balance paid',
                  value: _currency(currentBooking.balancePaid),
                ),
                if (currentBooking.isCancelled)
                  _ReceiptRow(
                    label: 'Refunded',
                    value: _currency(currentBooking.refundedAmount),
                  ),
                _ReceiptRow(
                  label: 'Remaining',
                  value: _currency(currentBooking.remainingAmount),
                  emphasize: true,
                  valueColor: currentBooking.isPaymentDueOn(DateTime.now())
                      ? AppColors.expenseDark
                      : null,
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: currentBooking.isPaymentDueOn(DateTime.now())
                        ? AppColors.expenseSoft
                        : AppColors.appBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    currentBooking.isCancelled
                        ? 'Cancelled booking'
                        : currentBooking.remainingAmount > 0
                        ? '${currentBooking.isPaymentDueOn(DateTime.now()) ? 'Payment due' : 'Balance due'} on ${_formatDate(currentBooking.checkIn)}'
                        : 'Paid in full',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: currentBooking.isPaymentDueOn(DateTime.now())
                          ? AppColors.expenseDark
                          : AppColors.brandPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (actionError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 72),
                  child: SingleChildScrollView(
                    child: Text(
                      actionError!,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: IconButton(
                      tooltip: 'Record payment',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed:
                          saving ||
                              currentBooking.isCancelled ||
                              currentBooking.remainingAmount <= 0
                          ? null
                          : () async {
                              final updated = await showDialog<Booking>(
                                context: dialogContext,
                                barrierDismissible: false,
                                builder: (_) => _BookingPaymentDialog(
                                  booking: currentBooking,
                                  controller: widget.controller,
                                ),
                              );
                              if (updated != null && dialogContext.mounted) {
                                setDialogState(() => currentBooking = updated);
                                if (mounted) setState(() {});
                              }
                            },
                      icon: const Icon(Icons.payments_outlined),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: IconButton(
                      tooltip: 'Modify',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.appBackground,
                        foregroundColor: AppColors.brandPrimary,
                        minimumSize: const Size(48, 48),
                        side: BorderSide(
                          color: AppColors.brandPrimary.withValues(alpha: 0.25),
                        ),
                      ),
                      onPressed: saving || currentBooking.isCancelled
                          ? null
                          : () {
                              Navigator.of(dialogContext).pop();
                              _BookingsScreenState._editBooking(
                                this.context,
                                widget.controller,
                                currentBooking,
                              );
                            },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: IconButton(
                      tooltip: currentBooking.isCancelled
                          ? 'Record full refund'
                          : 'Cancel booking',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.expenseSoft,
                        foregroundColor: AppColors.expenseDark,
                        minimumSize: const Size(48, 48),
                        side: BorderSide(
                          color: AppColors.expenseDark.withValues(alpha: 0.35),
                        ),
                      ),
                      onPressed:
                          saving ||
                              (currentBooking.isCancelled &&
                                  (currentBooking.refundedAmount >=
                                          currentBooking.grossPaid ||
                                      currentBooking.grossPaid <= 0))
                          ? null
                          : () async {
                              final refund = currentBooking.isCancelled;
                              final confirmed = await showDialog<bool>(
                                context: dialogContext,
                                builder: (confirmContext) => AlertDialog(
                                  title: Text(
                                    refund
                                        ? 'Record full refund?'
                                        : 'Cancel booking?',
                                  ),
                                  content: Text(
                                    refund
                                        ? 'Confirm that ${_currency(currentBooking.grossPaid)} has already been returned to the guest. This only records the refund; it does not transfer money.'
                                        : 'The booking will be cancelled and removed from the calendar. Payments remain recorded, and you can record a full refund later.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(confirmContext, false),
                                      child: const Text('Go back'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(confirmContext, true),
                                      child: Text(
                                        refund
                                            ? 'Confirm refund'
                                            : 'Confirm cancellation',
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true || !dialogContext.mounted) {
                                return;
                              }
                              setDialogState(() {
                                saving = true;
                                actionError = null;
                              });
                              try {
                                final updated = refund
                                    ? await widget.controller.refundBooking(
                                        currentBooking.id,
                                      )
                                    : await widget.controller.cancelBooking(
                                        currentBooking.id,
                                      );
                                if (!dialogContext.mounted || !mounted) return;
                                setDialogState(() {
                                  currentBooking = updated;
                                  saving = false;
                                });
                                setState(() {});
                              } catch (e) {
                                if (!dialogContext.mounted || !mounted) return;
                                setDialogState(() {
                                  saving = false;
                                  actionError = refund
                                      ? 'Unable to record refund: $e'
                                      : 'Unable to cancel booking: $e';
                                });
                              }
                            },
                      icon: Icon(
                        currentBooking.isCancelled
                            ? Icons.assignment_return_outlined
                            : Icons.cancel_outlined,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: IconButton(
                      tooltip: 'Reprint receipt',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.appBackground,
                        foregroundColor: AppColors.brandPrimary,
                        minimumSize: const Size(48, 48),
                        side: BorderSide(
                          color: AppColors.brandPrimary.withValues(alpha: 0.25),
                        ),
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              setDialogState(() {
                                saving = true;
                                actionError = null;
                              });
                              try {
                                final matches = widget.controller.bookings
                                    .where(
                                      (item) => item.id == currentBooking.id,
                                    );
                                if (matches.isEmpty) {
                                  throw StateError(
                                    'Booking is no longer available.',
                                  );
                                }
                                final latest = matches.first;
                                final bytes =
                                    await _BookingsScreenState._buildBookingReceiptPdf(
                                      latest,
                                      guestHouseName: widget.guestHouseName,
                                      guestHouseAddress:
                                          widget.guestHouseAddress,
                                      guestHousePhotoBytes:
                                          widget.guestHousePhotoBytes,
                                      houseRules: widget.controller.houseRules,
                                    );
                                await Printing.layoutPdf(
                                  name: 'Booking receipt ${latest.id}',
                                  onLayout: (_) async => bytes,
                                );
                                if (!dialogContext.mounted || !mounted) return;
                                setDialogState(() => currentBooking = latest);
                              } catch (e) {
                                if (!dialogContext.mounted || !mounted) return;
                                setDialogState(
                                  () => actionError =
                                      'Unable to print receipt: $e',
                                );
                              } finally {
                                if (dialogContext.mounted && mounted) {
                                  setDialogState(() => saving = false);
                                }
                              }
                            },
                      icon: const Icon(Icons.print_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                autofocus: true,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final allBookings = widget.controller.bookings;
    final dueBookings =
        allBookings.where((booking) => booking.isPaymentDueOn(now)).toList()
          ..sort((a, b) => a.checkIn.compareTo(b.checkIn));
    final selectedDateBookings = allBookings
        .where((booking) => _isStayDate(booking, _selectedDate))
        .toList();
    final upcomingBookings = widget.controller.topUpcomingBookings.take(4);
    final localizations = MaterialLocalizations.of(context);

    return Container(
      color: AppColors.appBackground,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Home',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            localizations.formatMonthYear(now),
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          _HomeSectionCard(
            title: 'Stay calendar',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  tooltip: 'Previous month',
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  localizations.formatMonthYear(_visibleMonth),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
                  tooltip: 'Next month',
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    _CalendarWeekday('M'),
                    _CalendarWeekday('T'),
                    _CalendarWeekday('W'),
                    _CalendarWeekday('T'),
                    _CalendarWeekday('F'),
                    _CalendarWeekday('S'),
                    _CalendarWeekday('S'),
                  ],
                ),
                const SizedBox(height: 8),
                _buildCalendar(allBookings),
                const SizedBox(height: 10),
                const Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _CalendarLegend(
                      color: AppColors.brandPrimary,
                      label: 'Stay',
                    ),
                    _CalendarLegend(
                      color: AppColors.revenueSoft,
                      label: 'Today',
                    ),
                    _CalendarLegend(
                      color: AppColors.expenseDark,
                      label: 'Payment due',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    localizations.formatMediumDate(_selectedDate),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (selectedDateBookings.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No guest stays on this date.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  )
                else
                  ...selectedDateBookings.map(
                    (booking) => Card(
                      key: ValueKey('selected-date-booking-${booking.id}'),
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      color: booking.isPaymentDueOn(now)
                          ? AppColors.expenseSoft
                          : AppColors.revenueSoft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: booking.isPaymentDueOn(now)
                              ? AppColors.expenseDark.withValues(alpha: 0.45)
                              : AppColors.revenueDark.withValues(alpha: 0.45),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        dense: true,
                        leading: Icon(
                          Icons.person_outline,
                          color: booking.isPaymentDueOn(now)
                              ? AppColors.expenseDark
                              : AppColors.revenueDark,
                        ),
                        title: Text(
                          booking.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${_formatDate(booking.checkIn)} – ${_formatDate(booking.checkOut)}',
                        ),
                        trailing: Text(
                          booking.isPaymentDueOn(now)
                              ? 'Payment due'
                              : '${booking.guests} guests',
                          style: TextStyle(
                            color: booking.isPaymentDueOn(now)
                                ? AppColors.expenseDark
                                : AppColors.revenueDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () => _showBookingDetails(booking),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _HomeSectionCard(
            title: 'Upcoming bookings',
            child: upcomingBookings.isEmpty
                ? const Text(
                    'No upcoming bookings.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  )
                : Column(
                    children: upcomingBookings
                        .map(
                          (booking) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: const Icon(
                              Icons.event_available_outlined,
                              color: AppColors.revenueDark,
                            ),
                            title: Text(booking.name),
                            subtitle: Text(
                              '${_formatDate(booking.checkIn)} – ${_formatDate(booking.checkOut)}',
                            ),
                            trailing: Text(
                              _currency(booking.remainingAmount),
                              style: TextStyle(
                                color: booking.isPaymentDueOn(now)
                                    ? AppColors.expenseDark
                                    : null,
                              ),
                            ),
                            onTap: () => _showBookingDetails(booking),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),
          if (dueBookings.isNotEmpty) ...[
            _HomeSectionCard(
              title: 'Payments due',
              child: Column(
                children: dueBookings
                    .map(
                      (booking) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(
                          Icons.payment_outlined,
                          color: AppColors.expenseDark,
                        ),
                        title: Text(booking.name),
                        subtitle: Text(
                          'Due ${_formatDate(booking.checkIn)}',
                          style: const TextStyle(color: AppColors.expenseDark),
                        ),
                        trailing: Text(
                          _currency(booking.remainingAmount),
                          style: const TextStyle(
                            color: AppColors.expenseDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () => _showBookingDetails(booking),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendar(List<Booking> bookings) {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final leadingDays = firstOfMonth.weekday - DateTime.monday;
    final cellCount = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cellCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final dayNumber = index - leadingDays + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }

        final date = DateTime(
          _visibleMonth.year,
          _visibleMonth.month,
          dayNumber,
        );
        final hasStay = bookings.any((booking) => _isStayDate(booking, date));
        final hasPaymentDue = bookings.any(
          (booking) =>
              _isStayDate(booking, date) &&
              booking.isPaymentDueOn(DateTime.now()),
        );
        final isToday = DateUtils.isSameDay(date, DateTime.now());
        final isSelected = DateUtils.isSameDay(date, _selectedDate);
        final backgroundColor = hasStay
            ? (hasPaymentDue ? AppColors.expenseDark : AppColors.brandPrimary)
            : isToday
            ? AppColors.revenueSoft
            : Colors.transparent;
        final foregroundColor = hasStay ? Colors.white : AppColors.textStrong;

        return InkWell(
          key: ValueKey('calendar-date-${date.year}-${date.month}-${date.day}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _selectedDate = date);
            if (!hasStay) widget.onAddBookingForDate(date);
          },
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: isSelected && !hasStay
                  ? Border.all(color: AppColors.brandPrimary, width: 1.4)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: TextStyle(
                    color: foregroundColor,
                    fontWeight: hasStay || isToday || isSelected
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
                if (hasStay)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BookingDetailHeading extends StatelessWidget {
  const _BookingDetailHeading({
    required this.title,
    this.status,
    this.cancelled = false,
  });

  final String title;
  final String? status;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textStrong,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (status != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cancelled ? AppColors.expenseSoft : AppColors.revenueSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cancelled
                    ? AppColors.expenseDark
                    : AppColors.revenueDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _BookingPaymentDialog extends StatefulWidget {
  const _BookingPaymentDialog({
    required this.booking,
    required this.controller,
  });

  final Booking booking;
  final RegistryViewModel controller;

  @override
  State<_BookingPaymentDialog> createState() => _BookingPaymentDialogState();
}

class _BookingPaymentDialogState extends State<_BookingPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.booking.remainingAmount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.controller.recordBookingPayment(
        widget.booking.id,
        double.parse(_amountController.text.trim()),
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to record payment: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Record payment'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Remaining: ${_currency(widget.booking.remainingAmount)}'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  enabled: !_saving,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Payment amount',
                    prefixText: 'Rs ',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
                      return 'Enter an amount with up to 2 decimal places';
                    }
                    final amount = double.tryParse(text);
                    if (amount == null || !amount.isFinite || amount <= 0) {
                      return 'Enter an amount greater than zero';
                    }
                    if (amount - widget.booking.remainingAmount > 0.000001) {
                      return 'Payment cannot exceed the remaining balance';
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Saving...' : 'Save payment'),
          ),
        ],
      ),
    );
  }
}

class _HomeSectionCard extends StatelessWidget {
  const _HomeSectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _CalendarWeekday extends StatelessWidget {
  const _CalendarWeekday(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
      ],
    );
  }
}
