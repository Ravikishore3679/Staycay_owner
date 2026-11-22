import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/repositories/account_profile_repository.dart';
import '../theme/app_colors.dart';
import '../viewmodels/auth_view_model.dart';

class AccountProfileScreen extends StatefulWidget {
  const AccountProfileScreen({
    super.key,
    required this.user,
    required this.repository,
    required this.authViewModel,
    this.pickPhoto,
    this.onboarding = false,
    this.onComplete,
    this.initialGuestHouseName = '',
    this.initialGuestHouseAddress = '',
  }) : assert(!onboarding || onComplete != null);

  final User user;
  final AccountProfileRepository repository;
  final AuthViewModel authViewModel;
  final Future<Uint8List?> Function()? pickPhoto;
  final bool onboarding;
  final VoidCallback? onComplete;
  final String initialGuestHouseName;
  final String initialGuestHouseAddress;

  @override
  State<AccountProfileScreen> createState() => _AccountProfileScreenState();
}

class _AccountProfileScreenState extends State<AccountProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _guestHouseName = TextEditingController();
  final _guestHouseAddress = TextEditingController();
  late Stream<AccountProfile?> _profileStream;
  Uint8List? _photo;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profileStream = widget.repository.watchProfile(widget.user.uid);
    if (widget.onboarding) {
      _editing = true;
      _name.text = widget.user.displayName ?? '';
      _phone.text = widget.user.phoneNumber ?? '';
      _email.text = widget.user.email ?? '';
      _guestHouseName.text = widget.initialGuestHouseName;
      _guestHouseAddress.text = widget.initialGuestHouseAddress;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _guestHouseName.dispose();
    _guestHouseAddress.dispose();
    super.dispose();
  }

  AccountProfile get _defaultProfile => AccountProfile(
    name: widget.user.displayName ?? '',
    phone: widget.user.phoneNumber ?? '',
    email: widget.user.email ?? '',
    guestHouseName: widget.initialGuestHouseName,
    guestHouseAddress: widget.initialGuestHouseAddress,
  );

  void _edit(AccountProfile profile) {
    _name.text = profile.name;
    _phone.text = profile.phone;
    _email.text = profile.email;
    _guestHouseName.text = profile.guestHouseName.isEmpty
        ? widget.initialGuestHouseName
        : profile.guestHouseName;
    _guestHouseAddress.text =
        profile.guestHouseAddress ?? widget.initialGuestHouseAddress;
    setState(() {
      _photo = profile.photoBytes;
      _editing = true;
    });
  }

  Future<void> _pickPhoto() async {
    try {
      Uint8List? bytes;
      if (widget.pickPhoto != null) {
        bytes = await widget.pickPhoto!();
      } else {
        final file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 70,
        );
        bytes = await file?.readAsBytes();
      }
      if (bytes == null) return;
      if (!mounted) return;
      if (bytes.length > 500000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a photo smaller than 500 KB.')),
        );
        return;
      }
      setState(() => _photo = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to select photo: $e')));
    }
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.repository.saveProfile(
        widget.user.uid,
        AccountProfile(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          guestHouseName: _guestHouseName.text.trim(),
          guestHouseAddress: _guestHouseAddress.text.trim(),
          photoBytes: _photo,
        ),
      );
      if (!mounted) return;
      if (widget.onboarding) {
        widget.onComplete!();
        return;
      }
      setState(() => _editing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to save profile: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _skip() async {
    if (_saving) return;
    setState(() => _saving = true);
    final name = (widget.user.displayName ?? '').trim();
    final phone = (widget.user.phoneNumber ?? '').trim();
    final email = (widget.user.email ?? '').trim();
    try {
      await widget.repository.createProfileIfAbsent(
        widget.user.uid,
        AccountProfile(
          name: name.isEmpty || name.length > 80 ? 'Account' : name,
          phone: phone.length > 30 ? '' : phone,
          email: email.length > 254 ? '' : email,
        ),
      );
      if (!mounted) return;
      widget.onComplete!();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to continue: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _saving = true);
    try {
      await widget.authViewModel.signOut();
      if (!mounted) return;
      if (widget.onboarding) return;
      setState(() => _saving = false);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign-out failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('My profile')),
        body: StreamBuilder<AccountProfile?>(
          stream: _profileStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Unable to load profile: ${snapshot.error}'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => setState(() {
                          _profileStream = widget.repository.watchProfile(
                            widget.user.uid,
                          );
                        }),
                        child: const Text('Retry'),
                      ),
                      TextButton(
                        onPressed: _saving ? null : _signOut,
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final profile = snapshot.data ?? _defaultProfile;
            final guestHouseName = profile.guestHouseName.isEmpty
                ? widget.initialGuestHouseName
                : profile.guestHouseName;
            final guestHouseAddress =
                profile.guestHouseAddress ?? widget.initialGuestHouseAddress;
            final photo = _editing ? _photo : profile.photoBytes;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: AppColors.revenueSoft,
                          foregroundImage: photo == null
                              ? null
                              : MemoryImage(photo),
                          child: photo == null
                              ? const Icon(
                                  Icons.person_outline,
                                  size: 44,
                                  color: AppColors.revenueDark,
                                )
                              : null,
                        ),
                      ),
                      if (_editing) ...[
                        TextButton.icon(
                          onPressed: _saving ? null : _pickPhoto,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: Text(
                            photo == null ? 'Add photo' : 'Change photo',
                          ),
                        ),
                        if (photo != null)
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _photo = null),
                            child: const Text('Remove photo'),
                          ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Text(
                          profile.name.isEmpty ? 'Your profile' : profile.name,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _editing
                              ? _editForm()
                              : Column(
                                  children: [
                                    _ProfileDetail(
                                      icon: Icons.home_work_outlined,
                                      label: 'Guest house name',
                                      value: guestHouseName,
                                    ),
                                    const Divider(),
                                    _ProfileDetail(
                                      icon: Icons.location_on_outlined,
                                      label: 'Guest house address',
                                      value: guestHouseAddress,
                                    ),
                                    const Divider(),
                                    _ProfileDetail(
                                      icon: Icons.person_outline,
                                      label: 'Name',
                                      value: profile.name,
                                    ),
                                    const Divider(),
                                    _ProfileDetail(
                                      icon: Icons.phone_outlined,
                                      label: 'Phone number',
                                      value: profile.phone,
                                    ),
                                    const Divider(),
                                    _ProfileDetail(
                                      icon: Icons.email_outlined,
                                      label: 'Email',
                                      value: profile.email,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'These are contact details and do not change your sign-in credentials.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_editing) ...[
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? 'Saving...' : 'Save changes'),
                        ),
                        if (widget.onboarding)
                          TextButton(
                            onPressed: _saving ? null : _skip,
                            child: const Text('Skip for now'),
                          )
                        else
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _editing = false),
                            child: const Text('Cancel'),
                          ),
                        if (widget.onboarding)
                          TextButton(
                            onPressed: _saving ? null : _signOut,
                            child: const Text('Sign out'),
                          ),
                      ] else ...[
                        FilledButton.icon(
                          onPressed: _saving ? null : () => _edit(profile),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit profile'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _signOut,
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign out'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _editForm() => Form(
    key: _formKey,
    child: Column(
      children: [
        TextFormField(
          controller: _guestHouseName,
          enabled: !_saving,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Guest house name',
            prefixIcon: Icon(Icons.home_work_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _guestHouseAddress,
          enabled: !_saving,
          maxLength: 250,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Guest house address',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _name,
          enabled: !_saving,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (value) =>
              (value?.trim().isEmpty ?? true) ? 'Enter your name' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phone,
          enabled: !_saving,
          maxLength: 30,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          validator: (value) {
            final phone = value?.trim() ?? '';
            if (phone.isNotEmpty &&
                !RegExp(r'^\+?[0-9 ()-]{6,30}$').hasMatch(phone)) {
              return 'Enter a valid phone number';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _email,
          enabled: !_saving,
          maxLength: 254,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: (value) {
            final email = value?.trim() ?? '';
            if (email.isNotEmpty &&
                !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
              return 'Enter a valid email address';
            }
            return null;
          },
        ),
      ],
    ),
  );
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: AppColors.revenueDark),
    title: Text(label, style: Theme.of(context).textTheme.bodySmall),
    subtitle: Text(
      value.isEmpty ? 'Not provided' : value,
      style: Theme.of(context).textTheme.bodyLarge,
    ),
  );
}
