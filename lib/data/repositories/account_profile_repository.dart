import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

class AccountProfile {
  const AccountProfile({
    required this.name,
    required this.phone,
    required this.email,
    this.guestHouseName = '',
    this.guestHouseAddress,
    this.photoBytes,
  });

  final String name;
  final String phone;
  final String email;
  final String guestHouseName;
  final String? guestHouseAddress;
  final Uint8List? photoBytes;
}

abstract class AccountProfileRepository {
  Stream<AccountProfile?> watchProfile(String uid);
  Future<void> saveProfile(String uid, AccountProfile profile);
  Future<void> createProfileIfAbsent(String uid, AccountProfile profile);
}

class FirestoreAccountProfileRepository implements AccountProfileRepository {
  FirestoreAccountProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _document(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('account')
      .doc('profile');

  @override
  Stream<AccountProfile?> watchProfile(String uid) =>
      _document(uid).snapshots().map((snapshot) {
        final data = snapshot.data();
        if (data == null) return null;
        final photo = data['photoBytes'];
        return AccountProfile(
          name: data['name'] is String ? data['name'] as String : '',
          phone: data['phone'] is String ? data['phone'] as String : '',
          email: data['email'] is String ? data['email'] as String : '',
          guestHouseName: data['guestHouseName'] is String
              ? data['guestHouseName'] as String
              : '',
          guestHouseAddress: data['guestHouseAddress'] is String
              ? data['guestHouseAddress'] as String
              : null,
          photoBytes: photo is Blob ? photo.bytes : null,
        );
      });

  @override
  Future<void> saveProfile(String uid, AccountProfile profile) =>
      _document(uid).set(_data(profile));

  @override
  Future<void> createProfileIfAbsent(String uid, AccountProfile profile) =>
      _firestore.runTransaction((transaction) async {
        final document = _document(uid);
        final snapshot = await transaction.get(document);
        if (!snapshot.exists) transaction.set(document, _data(profile));
      });

  Map<String, dynamic> _data(AccountProfile profile) => {
    'name': profile.name,
    'phone': profile.phone,
    'email': profile.email,
    'guestHouseName': profile.guestHouseName,
    if (profile.guestHouseAddress != null)
      'guestHouseAddress': profile.guestHouseAddress,
    'photoBytes': profile.photoBytes == null ? null : Blob(profile.photoBytes!),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
