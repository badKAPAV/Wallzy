import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/goal_model.dart';

class GoalsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Goal>> getGoalsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('goals')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Goal.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  Future<Goal> addGoal(String userId, Goal goal) async {
    final docRef = await _firestore
        .collection('users')
        .doc(userId)
        .collection('goals')
        .add(goal.toMap());

    return goal.copyWith(id: docRef.id);
  }

  Future<void> updateGoal(String userId, Goal goal) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('goals')
        .doc(goal.id)
        .update(goal.toMap());
  }

  Future<void> deleteGoal(String userId, String goalId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('goals')
        .doc(goalId)
        .delete();
  }
}
