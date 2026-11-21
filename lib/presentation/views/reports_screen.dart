part of 'registry_home_page.dart';

Future<Uint8List> buildMonthlyReportPdf({
  required MonthlyReport report,
  required List<Booking> bookings,
  required List<Expense> expenses,
}) async {
  final activeBookings = bookings.where((booking) => !booking.isCancelled);
  final cancelledBookings = bookings.where((booking) => booking.isCancelled);
  final pdf = pw.Document();

  pw.Widget heading(String title, int count) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
    child: pw.Text(
      '$title ($count)',
      style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
    ),
  );

  pw.Widget row(String label, double amount, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          _currency(amount),
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    ),
  );

  List<pw.Widget> bookingDetails(Booking booking) => [
    pw.Text(
      booking.name,
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      overflow: pw.TextOverflow.span,
    ),
    pw.Text(
      'Check-in: ${_formatDate(booking.checkIn)}  |  Check-out: ${_formatDate(booking.checkOut)}',
    ),
    pw.Text(
      'Guests: ${booking.guests}  |  Total: ${_currency(booking.totalAmount)}',
    ),
    pw.Text(
      'Advance: ${_currency(booking.advancePaid)}  |  Balance paid: ${_currency(booking.balancePaid)}',
    ),
    pw.Text(
      'Refunded: ${_currency(booking.refundedAmount)}  |  Revenue: ${_currency(booking.collectedAmount)}',
    ),
    if (!booking.isCancelled)
      pw.Text('Remaining: ${_currency(booking.remainingAmount)}'),
    pw.Divider(),
    pw.SizedBox(height: 10),
  ];

  pdf.addPage(
    pw.MultiPage(
      margin: const pw.EdgeInsets.all(32),
      maxPages: 10000,
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ),
      build: (context) => [
        pw.Text(
          'Monthly Profit & Loss',
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          '${_monthName(report.month)} ${report.year}',
          style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Bookings, including cancellations, are listed by check-in month. Expenses are listed by expense date. Revenue is net of recorded refunds.',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 12),
        row('Revenue after refunds', report.revenue),
        row('Expenses', report.expenses),
        pw.Divider(),
        row('Net profit / loss', report.net, bold: true),
        heading('Bookings', activeBookings.length),
        if (activeBookings.isEmpty) pw.Text('No active bookings this month.'),
        ...activeBookings.expand(bookingDetails),
        heading('Cancelled bookings', cancelledBookings.length),
        if (cancelledBookings.isEmpty)
          pw.Text('No cancelled bookings this month.'),
        ...cancelledBookings.expand(bookingDetails),
        heading('Expenses', expenses.length),
        if (expenses.isEmpty) pw.Text('No expenses this month.'),
        ...expenses.expand(
          (expense) => [
            pw.Text(
              expense.title,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              overflow: pw.TextOverflow.span,
            ),
            pw.Text(
              '${_formatDate(expense.date)}  |  ${_currency(expense.amount)}',
            ),
            if (expense.description.trim().isNotEmpty)
              pw.Text(
                'Description: ${expense.description}',
                overflow: pw.TextOverflow.span,
              ),
            pw.Divider(),
            pw.SizedBox(height: 10),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Generated ${_formatDate(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ],
    ),
  );
  return pdf.save();
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

  Future<void> _printMonthlyReport(MonthlyReport report) async {
    try {
      final bookings = List<Booking>.of(
        widget.controller.bookingsForMonth(report.year, report.month),
      );
      final expenses = List<Expense>.of(
        widget.controller.expensesForMonth(report.year, report.month),
      );
      final bytes = await buildMonthlyReportPdf(
        report: report,
        bookings: bookings,
        expenses: expenses,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'monthly_pl_${report.year}_${report.month.toString().padLeft(2, '0')}.pdf',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monthly P&L ready to share or print')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate monthly P&L: $e')),
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
      for (
        int year = DateTime.now().year - 5;
        year <= DateTime.now().year + 1;
        year++
      )
        year,
    ];

    return Container(
      color: AppColors.appBackground,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Monthly P&L',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Revenue includes payments less recorded refunds for bookings checking in during the selected month.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
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
                        if (value != null) {
                          setState(() => _selectedMonth = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _selectedYear,
                      decoration: const InputDecoration(labelText: 'Year'),
                      items: [
                        for (final year in years)
                          DropdownMenuItem(value: year, child: Text('$year')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedYear = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                _ProfitLossRow(
                  label: 'Revenue after refunds',
                  amount: report.revenue,
                  icon: Icons.arrow_downward,
                  color: AppColors.revenueDark,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _ProfitLossRow(
                  label: 'Expenses',
                  amount: report.expenses,
                  icon: Icons.arrow_upward,
                  color: AppColors.expenseDark,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _ProfitLossRow(
                  label: 'Net profit / loss',
                  amount: report.net,
                  icon: report.net >= 0
                      ? Icons.account_balance_wallet_outlined
                      : Icons.warning_amber_outlined,
                  color: report.net >= 0
                      ? AppColors.revenueDark
                      : AppColors.expenseDark,
                  emphasize: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _printMonthlyReport(
              widget.controller.getMonthlyReport(_selectedYear, _selectedMonth),
            ),
            icon: const Icon(Icons.ios_share_outlined),
            label: const Text('Export monthly P&L'),
          ),
        ],
      ),
    );
  }
}

class _ProfitLossRow extends StatelessWidget {
  const _ProfitLossRow({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    this.emphasize = false,
  });

  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.1),
            foregroundColor: color,
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            _currency(amount),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
