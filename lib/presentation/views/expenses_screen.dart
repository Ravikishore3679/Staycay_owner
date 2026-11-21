part of 'registry_home_page.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    super.key,
    required this.controller,
  });

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

  @override
  Widget build(BuildContext context) {
    final lightTheme = _lightTabTheme(context);

    return Theme(
      data: lightTheme,
      child: Container(
        color: AppColors.appBackground,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                          labelText: 'Description (optional)',
                          hintText: 'Add notes (optional)',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.length > 500) {
                            return 'Description cannot exceed 500 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
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
          ],
        ),
      ),
    );
  }
}
