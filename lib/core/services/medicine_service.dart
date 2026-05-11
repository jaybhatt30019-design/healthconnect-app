import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healthconnect/models/medicine_model.dart';

class MedicineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _ref => _firestore.collection('medicines');

  /// ➕ ADD (Firestore auto-generates the doc ID)
  Future<void> addMedicine(Medicine med) async {
    await _ref.add(med.toMap(isNew: true));
  }

  /// ✏️ UPDATE — uses med.id to find the document
  Future<void> updateMedicine(Medicine med) async {
    await _ref.doc(med.id).update(med.toMap());
  }

  /// ❌ DELETE
  Future<void> deleteMedicine(String id) async {
    await _ref.doc(id).delete();
  }

  /// 🔥 REALTIME STREAM
  Stream<List<Medicine>> getMedicines() {
    return _ref.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Medicine.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    });
  }
}