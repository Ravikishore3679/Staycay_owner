part of 'registry_home_page.dart';

class AddScreen extends StatefulWidget {
  const AddScreen({
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
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
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

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Add a record',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose what you want to add.',
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
      ],
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
              tooltip: 'Back to add options',
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
