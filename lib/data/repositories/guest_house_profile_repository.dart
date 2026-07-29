import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

class GuestHouseProfileData {
  GuestHouseProfileData({
    required this.name,
    required this.address,
    required this.photoBytes,
    this.email,
  });

  final String name;
  final String address;
  final Uint8List photoBytes;
  final String? email;
}

class GuestHouseProfileRepository {
  GuestHouseProfileRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _profileDocument(String uid) =>
      _firestore.collection('users').doc(uid).collection('profile').doc('main');

  Future<GuestHouseProfileData?> loadProfile({required String uid}) async {
    final snapshot = await _profileDocument(uid).get();
    if (!snapshot.exists) return null;

    final data = snapshot.data();
    if (data == null) return null;

    final photoBytes = _decodePhotoBytes(data['photoBytes']);
    if (photoBytes == null) return null;

    return GuestHouseProfileData(
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      photoBytes: photoBytes,
      email: data['email'] as String?,
    );
  }

  Future<void> saveProfile({
    required String uid,
    required String name,
    required String address,
    required Uint8List photoBytes,
    String? email,
  }) async {
    final data = <String, dynamic>{
      'name': name,
      'address': address,
      'photoBytes': Blob(photoBytes),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (email != null && email.isNotEmpty) {
      data['email'] = email;
    }

    await _profileDocument(uid).set(data, SetOptions(merge: true));
  }

  Uint8List? _decodePhotoBytes(dynamic value) {
    if (value is Blob) {
      return value.bytes;
    }

    if (value is Uint8List) {
      return value;
    }

    if (value is List<int>) {
      return Uint8List.fromList(value);
    }

    return null;
  }
}