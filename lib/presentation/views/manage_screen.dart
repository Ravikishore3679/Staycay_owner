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
                : _WebsiteTab(controller: widget.controller),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Manage records',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
                icon: Icons.language_outlined,
                title: 'Website',
                subtitle: 'Open or share the website',
                onTap: () => setState(() => _selectedForm = 'website'),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 12, bottom: 4),
            child: TextButton(
              onPressed: () => setState(() => _selectedForm = 'houseRules'),
              child: const Text('House rules'),
            ),
          ),
        ),
      ],
    );
  }
}

class _WebsiteTab extends StatefulWidget {
  const _WebsiteTab({required this.controller});

  final RegistryViewModel controller;

  @override
  State<_WebsiteTab> createState() => _WebsiteTabState();
}

class _WebsiteTabState extends State<_WebsiteTab> {
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  late Stream<String?> _websiteStream;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _websiteStream = _watchWebsite();
  }

  Stream<String?> _watchWebsite() async* {
    yield* widget.controller.repository.watchWebsiteUrl();
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Uri? _parseAddress(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || RegExp(r'\s').hasMatch(trimmed)) return null;
    final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.host.contains(':') ||
        withScheme.length > 2048) {
      return null;
    }
    return uri;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final value = _address.text.trim();
    final url = value.isEmpty ? '' : _parseAddress(value)!.toString();
    setState(() => _saving = true);
    try {
      await widget.controller.repository.saveWebsiteUrl(url);
      if (!mounted) return;
      setState(() => _editing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Website saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to save website: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openWebsite(String url) async {
    try {
      final uri = _parseAddress(url);
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Invalid or unavailable website address.');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to open the website: $e')));
    }
  }

  Future<void> _copyLink(String url) async {
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Website link copied')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to copy the website link: $e')),
      );
    }
  }

  Future<void> _shareLink(String url, Rect origin) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: url, sharePositionOrigin: origin),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to share the website: $e')),
      );
    }
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
            'Add, open or share your website.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          StreamBuilder<String?>(
            stream: _websiteStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(
                  children: [
                    Text('Unable to load website: ${snapshot.error}'),
                    TextButton(
                      onPressed: () => setState(() {
                        _websiteStream = _watchWebsite();
                      }),
                      child: const Text('Retry'),
                    ),
                  ],
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final url = snapshot.data ?? '';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            child: Icon(Icons.language_outlined),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              url.isEmpty ? 'No website added' : url,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_editing) ...[
                        Form(
                          key: _formKey,
                          child: TextFormField(
                            key: const Key('websiteAddress'),
                            controller: _address,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              labelText: 'Website address',
                              hintText: 'example.com',
                              helperText: 'Leave empty to remove your website.',
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isNotEmpty &&
                                  _parseAddress(text) == null) {
                                return 'Enter a valid HTTP or HTTPS website address';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            TextButton(
                              onPressed: _saving
                                  ? null
                                  : () => setState(() => _editing = false),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              key: const Key('saveWebsite'),
                              onPressed: _saving ? null : _save,
                              child: Text(
                                _saving ? 'Saving...' : 'Save website',
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        OutlinedButton.icon(
                          key: const Key('editWebsite'),
                          onPressed: () => setState(() {
                            _address.text = url;
                            _editing = true;
                          }),
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(
                            url.isEmpty ? 'Add website' : 'Edit website',
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const Key('openWebsite'),
                            onPressed: url.isEmpty
                                ? null
                                : () => _openWebsite(url),
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
                                onPressed: url.isEmpty
                                    ? null
                                    : () => _copyLink(url),
                                icon: const Icon(Icons.copy_outlined),
                                label: const Text('Copy link'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Builder(
                                builder: (buttonContext) => OutlinedButton.icon(
                                  key: const Key('shareWebsiteLink'),
                                  onPressed: url.isEmpty
                                      ? null
                                      : () {
                                          final box =
                                              buttonContext.findRenderObject()!
                                                  as RenderBox;
                                          _shareLink(
                                            url,
                                            box.localToGlobal(Offset.zero) &
                                                box.size,
                                          );
                                        },
                                  icon: const Icon(Icons.share_outlined),
                                  label: const Text('Share'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
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
