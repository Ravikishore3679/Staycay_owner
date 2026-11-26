part of 'registry_home_page.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({
    super.key,
    required this.controller,
    required this.guestHouseName,
    required this.guestHouseAddress,
    required this.guestHousePhotoBytes,
    this.initialCheckIn,
  });

  final RegistryViewModel controller;
  final String guestHouseName;
  final String guestHouseAddress;
  final Uint8List? guestHousePhotoBytes;
  final DateTime? initialCheckIn;

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  static List<String> _ruleLines(String rules) => rules
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();
  final _guestsCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _advanceCtrl = TextEditingController();

  DateTime? _checkIn;
  DateTime? _checkOut;
  bool _checkoutManuallySelected = false;

  static DateTime _nextDay(DateTime date) =>
      DateTime(date.year, date.month, date.day + 1);

  @override
  void initState() {
    super.initState();
    final initialCheckIn = widget.initialCheckIn;
    if (initialCheckIn != null) {
      _checkIn = DateUtils.dateOnly(initialCheckIn);
      _checkOut = _nextDay(_checkIn!);
    }
  }

  static Widget _datePickerThemeWrapper(BuildContext context, Widget? child) {
    final base = Theme.of(context);
    final scheme = ColorScheme.fromSeed(
      seedColor: base.colorScheme.primary,
      brightness: Brightness.light,
    );

    return Theme(
      data: base.copyWith(
        colorScheme: scheme,
        datePickerTheme: DatePickerThemeData(
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent,
          headerBackgroundColor: scheme.primary,
          headerForegroundColor: scheme.onPrimary,
          dayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return scheme.onPrimary;
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.38);
            }
            return scheme.onSurface;
          }),
          dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return scheme.primary;
            return null;
          }),
          todayForegroundColor: WidgetStateProperty.all(scheme.primary),
          todayBorder: BorderSide(color: scheme.primary, width: 1.2),
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

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
      firstDate: DateTime(
        initialDate.year < now.year - 1 ? initialDate.year : now.year - 1,
      ),
      lastDate: DateTime(
        (initialDate.year > now.year + 5 ? initialDate.year : now.year + 5) + 1,
      ),
      builder: (pickerContext, child) =>
          _datePickerThemeWrapper(pickerContext, child),
    );

    if (selected == null || !mounted) return;

    setState(() {
      if (isCheckIn) {
        _checkIn = selected;
        if (!_checkoutManuallySelected ||
            _checkOut == null ||
            !_checkOut!.isAfter(selected)) {
          _checkOut = _nextDay(selected);
          _checkoutManuallySelected = false;
        }
      } else {
        _checkOut = selected;
        _checkoutManuallySelected = true;
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
      _checkoutManuallySelected = false;
    });
  }

  static double _toAmount(String value) => double.tryParse(value.trim()) ?? 0.0;

  static String? _validateGuests(String? value) {
    final guests = int.tryParse(value?.trim() ?? '');
    if (guests == null) return 'Guests count is required';
    if (guests < 1 || guests > 99) return 'Enter between 1 and 99 guests';
    return null;
  }

  static Future<Uint8List> _buildBookingReceiptPdf(
    Booking booking, {
    required String guestHouseName,
    required String guestHouseAddress,
    required Uint8List? guestHousePhotoBytes,
    required String houseRules,
  }) async {
    final pdf = pw.Document();
    final photoBytes = guestHousePhotoBytes;

    pw.Widget buildModernRow(
      String label,
      String value,
      PdfColor valueColor,
      bool hasBg,
      bool isBold,
    ) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: pw.BoxDecoration(
          color: hasBg ? PdfColors.grey50 : null,
          border: const pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Text(
                value,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  color: valueColor,
                  fontSize: 10,
                  fontWeight: isBold
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
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(
          32,
        ), // Increased margin for an elegant border breathing room
        build: (context) {
          // Professional executive color palette
          const primaryColor =
              PdfColors.blueGrey900; // Deep Navy/Slate for headers
          const accentColor =
              PdfColors.teal700; // Muted teal for highlight lines & tags
          const textDark = PdfColors.grey900; // Crisp readable text
          const textMuted = PdfColors.grey600; // Subtle secondary metadata
          //const bgLight = PdfColors.grey50;             // Zebra stripe background
          const bgHeader =
              PdfColors.blueGrey50; // Soft layout header background
          const alertColor =
              PdfColors.deepOrange800; // Contrast color for remaining dues

          return [
            // --- HEADER SECTION ---
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: bgHeader,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (photoBytes != null)
                    pw.Container(
                      width: 70,
                      height: 70,
                      margin: const pw.EdgeInsets.only(right: 16),
                      decoration: pw.BoxDecoration(
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(
                          color: PdfColors.grey300,
                          width: 1,
                        ),
                      ),
                      child: pw.ClipRRect(
                        horizontalRadius: 7,
                        verticalRadius: 7,
                        child: pw.Image(
                          pw.MemoryImage(photoBytes),
                          fit: pw.BoxFit.cover,
                        ),
                      ),
                    ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          guestHouseName.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (guestHouseAddress.trim().isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            guestHouseAddress,
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: textMuted,
                            ),
                          ),
                        ],
                        pw.SizedBox(height: 8),
                        pw.Container(
                          height: 1,
                          color: PdfColors.grey300,
                          margin: const pw.EdgeInsets.only(bottom: 8),
                        ),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'Receipt ID: ${booking.id}',
                                  style: pw.TextStyle(
                                    color: textDark,
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  'Issued On: ${_formatDate(DateTime.now())}',
                                  style: const pw.TextStyle(
                                    color: textMuted,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: const pw.BoxDecoration(
                                color: primaryColor,
                                borderRadius: pw.BorderRadius.all(
                                  pw.Radius.circular(4),
                                ),
                              ),
                              child: pw.Text(
                                'BOOKING RECEIPT',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // --- DETAILS SECTION TITLE ---
            pw.Text(
              'RESERVATION DETAILS',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
                letterSpacing: 0.8,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 2, color: accentColor),
            pw.SizedBox(height: 8),

            // --- GRID/TABLE DATA LIST ---
            // Helper closures for rendering elegant alternate rows
            buildModernRow('Guest Name', booking.name, textDark, false, false),
            buildModernRow('Phone', booking.phone, textDark, true, false),
            buildModernRow('Aadhaar', booking.aadhaar, textDark, false, false),
            buildModernRow(
              'Check-in',
              _formatDate(booking.checkIn),
              textDark,
              true,
              false,
            ),
            buildModernRow(
              'Check-out',
              _formatDate(booking.checkOut),
              textDark,
              false,
              false,
            ),
            buildModernRow(
              'Guests',
              booking.guests.toString(),
              textDark,
              false,
              false,
            ),
            buildModernRow(
              'Status',
              booking.isCancelled ? 'Cancelled' : 'Active',
              booking.isCancelled ? alertColor : textDark,
              false,
              true,
            ),
            buildModernRow(
              'Total Amount',
              _currency(booking.totalAmount),
              textDark,
              true,
              false,
            ),
            buildModernRow(
              'Advance Paid',
              _currency(booking.advancePaid),
              accentColor,
              false,
              true,
            ),
            if (booking.balancePaid > 0)
              buildModernRow(
                'Balance Paid',
                _currency(booking.balancePaid),
                accentColor,
                false,
                true,
              ),
            if (booking.isCancelled)
              buildModernRow(
                'Refunded',
                _currency(booking.refundedAmount),
                textDark,
                false,
                true,
              ),
            buildModernRow(
              'Remaining Amount',
              _currency(booking.remainingAmount),
              alertColor,
              true,
              true, // Bold text
            ),

            pw.SizedBox(height: 28),

            // --- HOUSE RULES SECTION ---
            pw.Text(
              'HOUSE & STAY RULES',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
                letterSpacing: 0.8,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 1.5, color: PdfColors.grey300),
            pw.SizedBox(height: 10),

            ..._ruleLines(houseRules).map(
              (rule) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      margin: const pw.EdgeInsets.only(top: 4, right: 8),
                      width: 4,
                      height: 4,
                      decoration: const pw.BoxDecoration(
                        color: accentColor,
                        shape: pw.BoxShape.circle,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        rule,
                        style: const pw.TextStyle(
                          color: textDark,
                          fontSize: 10,
                          lineSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Visual layout helper method for neat data alignments
  // ignore: unused_element
  pw.Widget _buildModernRow(
    String label,
    String value, [
    PdfColor valueColor = PdfColors.grey900,
    bool hasBg = false,
    bool isBold = false,
  ]) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pw.BoxDecoration(
        color: hasBg ? PdfColors.grey50 : null,
        border: const pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: valueColor,
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadBookingReceiptPdf(Booking booking) async {
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      final bytes = await _buildBookingReceiptPdf(
        booking,
        guestHouseName: widget.guestHouseName,
        guestHouseAddress: widget.guestHouseAddress,
        guestHousePhotoBytes: widget.guestHousePhotoBytes,
        houseRules: widget.controller.houseRules,
      );
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
      builder: (dialogContext) {
        final base = Theme.of(dialogContext);
        final scheme = ColorScheme.fromSeed(
          seedColor: base.colorScheme.primary,
          brightness: Brightness.light,
        );

        return Theme(
          data: base.copyWith(
            colorScheme: scheme,
            dialogTheme: DialogThemeData(backgroundColor: scheme.surface),
            textTheme: base.textTheme.apply(
              bodyColor: scheme.onSurface,
              displayColor: scheme.onSurface,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: scheme.primary),
            ),
          ),
          child: AlertDialog(
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
                        color: Theme.of(
                          dialogContext,
                        ).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.guestHouseName),
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
                    _ReceiptRow(
                      label: 'Guests',
                      value: booking.guests.toString(),
                    ),
                    _ReceiptRow(
                      label: 'Total Amount',
                      value: _currency(booking.totalAmount),
                    ),
                    _ReceiptRow(
                      label: 'Advance Paid',
                      value: _currency(booking.advancePaid),
                    ),
                    if (booking.balancePaid > 0)
                      _ReceiptRow(
                        label: 'Balance Paid',
                        value: _currency(booking.balancePaid),
                      ),
                    _ReceiptRow(
                      label: 'Remaining Amount',
                      value: _currency(booking.remainingAmount),
                      emphasize: true,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Stay Rules',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color.fromARGB(255, 10, 52, 6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._ruleLines(widget.controller.houseRules).map(
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
                  Navigator.of(dialogContext).pop();
                  if (!mounted) return;
                  await _downloadBookingReceiptPdf(booking);
                },
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Download PDF'),
              ),
              FilledButton(
                autofocus: true,
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _editBooking(
    BuildContext context,
    RegistryViewModel controller,
    Booking booking,
  ) async {
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
    var saving = false;
    String? saveError;

    final route = DialogRoute<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogBuilderContext, setDialogState) {
            final total = _toAmount(totalCtrl.text);
            final advance = _toAmount(advanceCtrl.text);
            final remaining = total - advance - booking.balancePaid;

            Future<void> pickDate({
              required BuildContext pickerContext,
              required bool isCheckIn,
            }) async {
              final now = DateTime.now();
              final selected = await showDatePicker(
                context: pickerContext,
                initialDate: isCheckIn ? checkIn : checkOut,
                firstDate: DateTime(
                  checkIn.year < now.year - 1 ? checkIn.year : now.year - 1,
                ),
                lastDate: DateTime(
                  (checkOut.year > now.year + 5
                          ? checkOut.year
                          : now.year + 5) +
                      1,
                ),
                builder: (context, child) =>
                    _datePickerThemeWrapper(context, child),
              );

              if (selected == null || !dialogBuilderContext.mounted) return;
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
                        style: const TextStyle(color: Color(0xFF0F172A)),
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
                        style: const TextStyle(color: Color(0xFF0F172A)),
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
                        style: const TextStyle(color: Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                          labelText: 'Aadhaar (optional)',
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isNotEmpty && v.length != 12) {
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
                              onTap: () => pickDate(
                                pickerContext: dialogBuilderContext,
                                isCheckIn: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DateField(
                              label: 'Check-out',
                              value: checkOut,
                              onTap: () => pickDate(
                                pickerContext: dialogBuilderContext,
                                isCheckIn: false,
                              ),
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
                        style: const TextStyle(color: Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                          labelText: 'No. of Guests',
                        ),
                        validator: _validateGuests,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: totalCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(color: Color(0xFF0F172A)),
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
                        style: const TextStyle(color: Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                          labelText: 'Advance Paid',
                        ),
                        validator: (value) {
                          final a = double.tryParse(value?.trim() ?? '');
                          final t = double.tryParse(totalCtrl.text.trim());
                          if (a == null) return 'Advance amount is required';
                          if (a < 0) return 'Advance cannot be negative';
                          if (t != null &&
                              a + booking.balancePaid > t + 0.000001) {
                            return 'Payments cannot exceed total';
                          }
                          return null;
                        },
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      if (booking.balancePaid > 0) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Balance paid: ${_currency(booking.balancePaid)}',
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Remaining: ${_currency(remaining)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (saveError != null)
                        Text(
                          saveError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          if (!checkOut.isAfter(checkIn)) {
                            setDialogState(() {
                              saveError =
                                  'Check-out must be after check-in date';
                            });
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                            saveError = null;
                          });
                          try {
                            final messenger = ScaffoldMessenger.of(context);
                            await controller.updateBooking(
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
                                balancePaid: booking.balancePaid,
                              ),
                            );

                            if (!dialogContext.mounted || !context.mounted) {
                              return;
                            }
                            Navigator.of(dialogContext).pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Booking updated successfully'),
                              ),
                            );
                          } catch (e) {
                            if (!dialogContext.mounted || !context.mounted) {
                              return;
                            }
                            setDialogState(() {
                              saving = false;
                              saveError = 'Failed to update booking: $e';
                            });
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
    await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;

    nameCtrl.dispose();
    phoneCtrl.dispose();
    aadhaarCtrl.dispose();
    guestsCtrl.dispose();
    totalCtrl.dispose();
    advanceCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _toAmount(_totalCtrl.text);
    final advance = _toAmount(_advanceCtrl.text);
    final remaining = total - advance;
    final baseTheme = Theme.of(context);
    final lightScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.brandPrimary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.brandPrimary,
          surface: Colors.white,
          onSurface: AppColors.textStrong,
          onSurfaceVariant: const Color(0xFF64748B),
        );
    final bookingTheme = baseTheme.copyWith(
      colorScheme: lightScheme,
      scaffoldBackgroundColor: AppColors.appBackground,
      textTheme: baseTheme.textTheme.apply(
        bodyColor: AppColors.textStrong,
        displayColor: AppColors.textStrong,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.brandPrimary,
            width: 1.5,
          ),
        ),
      ),
    );

    return Theme(
      data: bookingTheme,
      child: Container(
        color: AppColors.appBackground,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Guest details',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 14),
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
                          labelText: 'Aadhaar (optional)',
                          hintText: '12-digit Aadhaar number (optional)',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isNotEmpty && v.length != 12) {
                            return 'Aadhaar must be 12 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Stay and payment',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
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
                              validator: _validateGuests,
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
                                final t = double.tryParse(
                                  _totalCtrl.text.trim(),
                                );
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
          ],
        ),
      ),
    );
  }
}
