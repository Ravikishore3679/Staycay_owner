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
          Expanded(child: ExpensesScreen(controller: widget.controller)),
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

    if (selectedForm == 'houseRules' || selectedForm == 'website') {
      return Column(
        children: [
          _AddFormHeader(
            title: selectedForm == 'houseRules' ? 'House rules' : 'Website',
            onBack: () => setState(() => _selectedForm = null),
          ),
          Expanded(
            child: selectedForm == 'houseRules'
                ? _HouseRulesEditor(controller: widget.controller)
                : const _WebsiteTab(),
          ),
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
        _AddActionCard(
          icon: Icons.rule_outlined,
          title: 'House rules',
          subtitle: 'Edit the rules shared with guests',
          onTap: () => setState(() => _selectedForm = 'houseRules'),
        ),
        _AddActionCard(
          icon: Icons.language_outlined,
          title: 'Website',
          subtitle: 'Open or share the website',
          onTap: () => setState(() => _selectedForm = 'website'),
        ),
      ],
    );
  }
}

class _WebsiteTab extends StatelessWidget {
  const _WebsiteTab();

  static const String _websiteUrl = 'https://heavenrock.netlify.app';
  static const String _displayUrl = 'heavenrock.netlify.app';

  Future<void> _openWebsite(BuildContext context) async {
    final uri = Uri.parse(_websiteUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the website')),
      );
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _websiteUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Website link copied')));
  }

  Future<void> _shareLink() async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Visit Heaven Rock: https://heavenrock.netlify.app',
        subject: 'Heaven Rock website',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.appBackground,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Website',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Open or share the Heaven Rock resort website.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      CircleAvatar(child: Icon(Icons.language_outlined)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _displayUrl,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('openWebsite'),
                      onPressed: () => _openWebsite(context),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open website'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('copyWebsiteLink'),
                          onPressed: () => _copyLink(context),
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('Copy link'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('shareWebsiteLink'),
                          onPressed: _shareLink,
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Share'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HouseRulesEditor extends StatefulWidget {
  const _HouseRulesEditor({required this.controller});

  final RegistryViewModel controller;

  @override
  State<_HouseRulesEditor> createState() => _HouseRulesEditorState();
}

class _HouseRulesEditorState extends State<_HouseRulesEditor> {
  late final TextEditingController _rules;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rules = TextEditingController(text: widget.controller.houseRules);
  }

  @override
  void didUpdateWidget(covariant _HouseRulesEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_saving && _rules.text.isEmpty) {
      _rules.text = widget.controller.houseRules;
    }
  }

  @override
  void dispose() {
    _rules.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_rules.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('House rules cannot be empty')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.saveHouseRules(_rules.text);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('House rules saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to save house rules: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Container(
          color: AppColors.appBackground,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'House rules',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Edit the rules that guests receive with their booking.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _rules,
                    key: const Key('houseRulesBody'),
                    minLines: 14,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      alignLabelWithHint: true,
                      labelText: 'House rules',
                      hintText: 'Enter one rule per line...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('saveHouseRules'),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save house rules'),
                ),
              ),
            ],
          ),
        );
      },
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currency(expense.amount),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          IconButton(
                            tooltip: 'Delete expense',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.expenseDark,
                            ),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Delete expense?'),
                                  content: Text(
                                    'Delete "${expense.title}" (${_currency(expense.amount)})? This cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(
                                        dialogContext,
                                      ).pop(false),
                                      child: const Text('Keep expense'),
                                    ),
                                    FilledButton(
                                      autofocus: true,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.expenseDark,
                                      ),
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                              try {
                                await controller.deleteExpense(expense.id);
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to delete expense: $e',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
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
