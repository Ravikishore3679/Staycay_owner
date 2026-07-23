part of 'registry_home_page.dart';

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
        content: Text('Are you sure you want to delete "${expense.title}"?'),
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
    final report = widget.controller.getMonthlyReport(
      _selectedYear,
      _selectedMonth,
    );
    final years = [
      for (int y = DateTime.now().year - 2; y <= DateTime.now().year + 2; y++)
        y,
    ];
    final nightTheme = _nightTabTheme(context);

    final monthBookings = widget.controller.bookingsForMonth(
      _selectedYear,
      _selectedMonth,
    );
    final monthExpenses = widget.controller.expensesForMonth(
      _selectedYear,
      _selectedMonth,
    );

    return Theme(
      data: nightTheme,
      child: Container(
        color: AppColors.dashboardCanvas,
        child: ListView(
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
                              child: Text(
                                _monthName(month),
                                style: const TextStyle(
                                  color: AppColors.dashboardText,
                                ),
                              ),
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
                                child: Text(
                                  year.toString(),
                                  style: const TextStyle(
                                    color: AppColors.dashboardText,
                                  ),
                                ),
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
                    color: AppColors.dashboardAccent,
                    icon: Icons.trending_up,
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: _ReportCard(
                    title: 'Total Expenses',
                    value: _currency(report.expenses),
                    color: AppColors.dashboardAccent,
                    icon: Icons.trending_down,
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: _ReportCard(
                    title: 'Net Profit / Loss',
                    value: _currency(report.net),
                    color: AppColors.dashboardAccent,
                    icon: report.net >= 0
                        ? Icons.account_balance_wallet_outlined
                        : Icons.warning_amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (monthBookings.isNotEmpty) ...[
              _SectionTitle(
                icon: Icons.hotel,
                title: 'Bookings',
                subtitle:
                    'Manage bookings for ${_monthName(_selectedMonth)} $_selectedYear',
              ),
              const SizedBox(height: 12),
              ...monthBookings.map(
                (booking) => Card(
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.dashboardText,
                                        ),
                                  ),
                                  Text(
                                    booking.phone,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.dashboardText
                                              .withValues(alpha: 0.8),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _currency(booking.totalAmount),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.dashboardAccent,
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
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.dashboardText.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
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
                ),
              ),
              const SizedBox(height: 24),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No bookings for ${_monthName(_selectedMonth)} $_selectedYear',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.dashboardText.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            if (monthExpenses.isNotEmpty) ...[
              _SectionTitle(
                icon: Icons.receipt_long,
                title: 'Expenses',
                subtitle:
                    'Manage expenses for ${_monthName(_selectedMonth)} $_selectedYear',
              ),
              const SizedBox(height: 12),
              ...monthExpenses.map(
                (expense) => Card(
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.dashboardText,
                                        ),
                                  ),
                                  Text(
                                    expense.description,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.dashboardText
                                              .withValues(alpha: 0.8),
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _currency(expense.amount),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.dashboardAccent,
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
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.dashboardText.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
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
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No expenses for ${_monthName(_selectedMonth)} $_selectedYear',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.dashboardText.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
