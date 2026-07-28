import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';

class ProfileScreen extends StatefulWidget {
	const ProfileScreen({
		super.key,
		this.initialName,
		this.initialAddress,
		this.initialPhotoBytes,
		required this.onContinue,
	});

	final String? initialName;
	final String? initialAddress;
	final Uint8List? initialPhotoBytes;
	final Future<void> Function({
		required String name,
		required String address,
		required Uint8List photoBytes,
	})
	onContinue;

	@override
	State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
	final _formKey = GlobalKey<FormState>();
	final _nameCtrl = TextEditingController();
	final _addressCtrl = TextEditingController();
	final _picker = ImagePicker();

	Uint8List? _photoBytes;
	bool _isSaving = false;

	@override
	void initState() {
		super.initState();
		_nameCtrl.text = widget.initialName ?? '';
		_addressCtrl.text = widget.initialAddress ?? '';
		_photoBytes = widget.initialPhotoBytes;
	}

	@override
	void dispose() {
		_nameCtrl.dispose();
		_addressCtrl.dispose();
		super.dispose();
	}

	Future<void> _pickPhoto() async {
		try {
			final file = await _picker.pickImage(
				source: ImageSource.gallery,
				imageQuality: 85,
				maxWidth: 1600,
			);
			if (file == null) return;

			final bytes = await file.readAsBytes();
			if (!mounted) return;

			setState(() {
				_photoBytes = bytes;
			});
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Failed to pick image: $e')),
			);
		}
	}

	Future<void> _submit() async {
		final isValid = _formKey.currentState?.validate() ?? false;
		if (!isValid) return;

		final photo = _photoBytes;
		if (photo == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please add a guest house photo')),
			);
			return;
		}

		setState(() {
			_isSaving = true;
		});

		try {
			await widget.onContinue(
				name: _nameCtrl.text.trim(),
				address: _addressCtrl.text.trim(),
				photoBytes: photo,
			);
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Unable to continue: $e')),
			);
		} finally {
			if (!mounted) return;
			setState(() {
				_isSaving = false;
			});
		}
	}

	@override
	Widget build(BuildContext context) {
		final textTheme = Theme.of(context).textTheme;

		return Scaffold(
			body: Container(
				decoration: const BoxDecoration(
					gradient: LinearGradient(
						colors: [Color(0xFFE9F6F3), Color(0xFFF8FBFA)],
						begin: Alignment.topLeft,
						end: Alignment.bottomRight,
					),
				),
				child: SafeArea(
					child: Center(
						child: SingleChildScrollView(
							padding: const EdgeInsets.all(20),
							child: ConstrainedBox(
								constraints: const BoxConstraints(maxWidth: 520),
								child: Card(
									child: Padding(
										padding: const EdgeInsets.all(20),
										child: Form(
											key: _formKey,
											child: Column(
												crossAxisAlignment: CrossAxisAlignment.start,
												children: [
													Text(
														'Guest House Profile',
														style: textTheme.headlineSmall?.copyWith(
															fontWeight: FontWeight.w700,
															color: AppColors.dashboardText,
														),
													),
													const SizedBox(height: 6),
													Text(
														'Before you continue, add your guest house details.',
														style: textTheme.bodyMedium?.copyWith(
															color: AppColors.dashboardText.withValues(
																alpha: 0.75,
															),
														),
													),
													const SizedBox(height: 18),
													Center(
														child: Column(
															children: [
																InkWell(
																	onTap: _isSaving ? null : _pickPhoto,
																	borderRadius: BorderRadius.circular(70),
																	child: CircleAvatar(
																		radius: 62,
																		backgroundColor: const Color(0xFFD7E8E5),
																		backgroundImage: _photoBytes == null
																				? null
																				: MemoryImage(_photoBytes!),
																		child: _photoBytes == null
																				? const Icon(
																						Icons.add_a_photo_outlined,
																						size: 34,
																						color: Color(0xFF0A1D21),
																					)
																				: null,
																	),
																),
																const SizedBox(height: 10),
																TextButton.icon(
																	onPressed: _isSaving ? null : _pickPhoto,
																	icon: const Icon(Icons.photo_library_outlined),
																	label: Text(
																		_photoBytes == null
																				? 'Upload Guest House Photo'
																				: 'Change Photo',
																	),
																),
															],
														),
													),
													const SizedBox(height: 14),
													TextFormField(
														controller: _nameCtrl,
														enabled: !_isSaving,
														textCapitalization: TextCapitalization.words,
														decoration: const InputDecoration(
															labelText: 'Guest House Name',
															prefixIcon: Icon(Icons.home_work_outlined),
														),
														validator: (value) {
															final text = value?.trim() ?? '';
															if (text.isEmpty) {
																return 'Guest house name is required';
															}
															if (text.length < 3) {
																return 'Enter at least 3 characters';
															}
															return null;
														},
													),
													const SizedBox(height: 12),
													TextFormField(
														controller: _addressCtrl,
														enabled: !_isSaving,
														minLines: 3,
														maxLines: 4,
														textCapitalization: TextCapitalization.words,
														decoration: const InputDecoration(
															labelText: 'Guest House Address',
															alignLabelWithHint: true,
															prefixIcon: Icon(Icons.location_on_outlined),
														),
														validator: (value) {
															final text = value?.trim() ?? '';
															if (text.isEmpty) {
																return 'Address is required';
															}
															if (text.length < 10) {
																return 'Please enter a complete address';
															}
															return null;
														},
													),
													const SizedBox(height: 20),
													SizedBox(
														width: double.infinity,
														child: FilledButton.icon(
															onPressed: _isSaving ? null : _submit,
															icon: _isSaving
																	? const SizedBox(
																			width: 16,
																			height: 16,
																			child: CircularProgressIndicator(
																				strokeWidth: 2,
																			),
																		)
																	: const Icon(Icons.arrow_forward),
															label: Text(
																_isSaving ? 'Saving...' : 'Continue to Dashboard',
															),
														),
													),
												],
											),
										),
									),
								),
							),
						),
					),
				),
			),
		);
	}
}
