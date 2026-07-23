part of 'registry_home_page.dart';

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
                  fontWeight: emphasize
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
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
                _ReceiptRow(
                  label: 'Check-in',
                  value: _formatDate(booking.checkIn),
                ),
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
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
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
                        decoration: const InputDecoration(labelText: 'Aadhaar'),
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
                        decoration: const InputDecoration(
                          labelText: 'No. of Guests',
                        ),
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
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Total Amount',
                        ),
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
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Advance Paid',
                        ),
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
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
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
                          content: Text(
                            'Check-out must be after check-in date',
                          ),
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
    final nightTheme = _nightTabTheme(context);

    return Theme(
      data: nightTheme,
      child: Container(
        color: AppColors.dashboardCanvas,
        child: ListView(
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
                          if (v.length < 3) {
                            return 'Enter at least 3 characters';
                          }
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
                          if (v.length != 12) {
                            return 'Aadhaar must be 12 digits';
                          }
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
                                if (v == null) {
                                  return 'Guests count is required';
                                }
                                if (v <= 0) return 'Guests must be at least 1';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _totalCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Total Amount',
                                prefixText: 'Rs ',
                              ),
                              validator: (value) {
                                final v = double.tryParse(value?.trim() ?? '');
                                if (v == null) {
                                  return 'Total amount is required';
                                }
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Advance Paid',
                                prefixText: 'Rs ',
                              ),
                              validator: (value) {
                                final a = double.tryParse(value?.trim() ?? '');
                                final t = double.tryParse(_totalCtrl.text.trim());
                                if (a == null) {
                                  return 'Advance amount is required';
                                }
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
                                if (!(_formKey.currentState?.validate() ??
                                    false)) {
                                  return;
                                }
                                if (_checkIn == null || _checkOut == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please select both check-in and check-out dates',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                if (!_checkOut!.isAfter(_checkIn!)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Check-out must be after check-in date',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final booking = Booking(
                                  id: DateTime.now().microsecondsSinceEpoch
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
                                      content: Text(
                                        'Booking added successfully',
                                      ),
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
                                      content: Text(
                                        'Failed to add booking: $e',
                                      ),
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
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
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
        ),
      ),
    );
  }
}
