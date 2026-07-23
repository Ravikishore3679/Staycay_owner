part of 'registry_home_page.dart';

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
                    const SnackBar(
                      content: Text('Expense updated successfully'),
                    ),
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
    final nightTheme = _nightTabTheme(context);

    return Theme(
      data: nightTheme,
      child: Container(
        color: AppColors.dashboardCanvas,
        child: ListView(
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
                          if (v.length < 3) {
                            return 'Enter at least 3 characters';
                          }
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
                          if (v.length < 5) {
                            return 'Enter at least 5 characters';
                          }
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
                                if (!(_formKey.currentState?.validate() ??
                                    false)) {
                                  return;
                                }

                                try {
                                  await widget.controller.addExpense(
                                    Expense(
                                      id: DateTime.now().microsecondsSinceEpoch
                                          .toString(),
                                      title: _titleCtrl.text.trim(),
                                      amount: double.parse(
                                        _amountCtrl.text.trim(),
                                      ),
                                      description: _descriptionCtrl.text.trim(),
                                      date: DateTime.now(),
                                    ),
                                  );

                                  _clearForm();
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Expense added successfully',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to add expense: $e',
                                      ),
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
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: AppColors.dashboardAccent,
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
        ),
      ),
    );
  }
}
