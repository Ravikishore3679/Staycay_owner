part of 'registry_home_page.dart';

class ManageScreen extends StatefulWidget {
  const ManageScreen({
    super.key,
    required this.controller,
    required this.guestHouseName,
    required this.guestHouseAddress,
    required this.guestHousePhotoBytes,
  });

  final RegistryViewModel controller;
  final String guestHouseName;
  final String guestHouseAddress;
  final Uint8List? guestHousePhotoBytes;

  @override
  State<ManageScreen> createState() => _ManageScreenState();
}

class _ManageScreenState extends State<ManageScreen> {
  String? _selectedForm;

  @override
  Widget build(BuildContext context) {
    final selectedForm = _selectedForm;
    if (selectedForm == 'booking') {
      return Column(
        children: [
          _AddFormHeader(
            title: 'Add booking',
            onBack: () => setState(() => _selectedForm = null),
          ),
          Expanded(
            child: BookingsScreen(
              controller: widget.controller,
              guestHouseName: widget.guestHouseName,
              guestHouseAddress: widget.guestHouseAddress,
              guestHousePhotoBytes: widget.guestHousePhotoBytes,
            ),
          ),
        ],
      );
    }

    if (selectedForm == 'expense') {
      return Column(
        children: [
          _AddFormHeader(
            title: 'Add expense',
            onBack: () => setState(() => _selectedForm = null),
          ),
          Expanded(
            child: ExpensesScreen(
              controller: widget.controller,
            ),
          ),
        ],
      );
    }

    if (selectedForm == 'showExpenses') {
      return Column(
        children: [
          _AddFormHeader(
            title: 'Expenses this month',
            onBack: () => setState(() => _selectedForm = null),
          ),
          Expanded(child: _MonthExpensesList(controller: widget.controller)),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Manage records',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose what you want to add or view.',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 20),
        _AddActionCard(
          icon: Icons.bed_outlined,
          title: 'Add booking',
          subtitle: 'Guest, stay dates and payment',
          onTap: () => setState(() => _selectedForm = 'booking'),
        ),
        _AddActionCard(
          icon: Icons.receipt_long_outlined,
          title: 'Add expense',
          subtitle: 'Record a business expense',
          onTap: () => setState(() => _selectedForm = 'expense'),
        ),
        _AddActionCard(
          icon: Icons.list_alt_outlined,
          title: 'Show expenses',
          subtitle: 'All expenses of the current month',
          onTap: () => setState(() => _selectedForm = 'showExpenses'),
        ),
      ],
    );
  }
}

class _MonthExpensesList extends StatelessWidget {
  const _MonthExpensesList({required this.controller});

  final RegistryViewModel controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final now = DateTime.now();
        final expenses = List<Expense>.of(
          controller.expensesForMonth(now.year, now.month),
        )..sort((a, b) => b.date.compareTo(a.date));
        final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);

        return Container(
          color: AppColors.appBackground,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: Text(
                    '${_monthName(now.month)} ${now.year}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${expenses.length} ${expenses.length == 1 ? 'expense' : 'expenses'}',
                  ),
                  trailing: Text(
                    _currency(total),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.expenseDark,
                    ),
                  ),
                ),
              ),
              if (expenses.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No expenses this month.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                )
              else
                ...expenses.map(
                  (expense) => Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.receipt_long_outlined,
                        color: AppColors.expenseDark,
                      ),
                      title: Text(expense.title),
                      subtitle: Text(
                        expense.description.isEmpty
                            ? _formatDate(expense.date)
                            : '${_formatDate(expense.date)} · ${expense.description}',
                      ),
                      trailing: Text(_currency(expense.amount)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AddFormHeader extends StatelessWidget {
  const _AddFormHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.appBackground,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              tooltip: 'Back to manage options',
              icon: const Icon(Icons.arrow_back),
            ),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddActionCard extends StatelessWidget {
  const _AddActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.revenueSoft,
          foregroundColor: AppColors.revenueDark,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
