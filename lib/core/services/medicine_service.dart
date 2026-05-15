import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:healthconnect/models/medicine_model.dart';

class MedicineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _ref => _firestore.collection('medicines');

  Future<String?> _getCaregiverId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (!userDoc.exists) return null;

    final data = userDoc.data()!;
    final role = data['role'] as String? ?? '';

    if (role == 'caregiver') return uid;

    if (role == 'parent') {
      final caregiverId = data['caregiverId'] as String?;
      if (caregiverId != null && caregiverId.isNotEmpty) return caregiverId;
      return uid;
    }

    return uid;
  }

  Future<void> addMedicine(Medicine med) async {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) return;

    final map = med.toMap(isNew: true);
    map['caregiverId'] = caregiverId;
    await _ref.add(map);
  }

  Future<void> updateMedicine(Medicine med) async {
    await _ref.doc(med.id).update(med.toMap());
  }

  Future<void> deleteMedicine(String id) async {
    await _ref.doc(id).delete();
  }

  Stream<List<Medicine>> getMedicines() async* {
    final caregiverId = await _getCaregiverId();
    if (caregiverId == null) {
      yield [];
      return;
    }

    yield* _ref
        .where('caregiverId', isEqualTo: caregiverId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Medicine.fromFirestore(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }
}